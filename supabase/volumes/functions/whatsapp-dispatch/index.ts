// Sends queued customer messages through the WhatsApp Cloud API.
//
// The token never reaches the app: it enqueues rows with
// `rpc/enqueue_whatsapp_message` and this function (service-role only) drains
// them. Run it from the same cron as push-dispatch.
//
// Required env:
//   WHATSAPP_TOKEN             permanent/system-user token
//   WHATSAPP_PHONE_NUMBER_ID   sender phone number id
// Optional:
//   WHATSAPP_API_VERSION       default v21.0
//   WHATSAPP_TEMPLATE_RECEIPT  default `receipt`     (body params: plate, amount, ticket)
//   WHATSAPP_TEMPLATE_PASS     default `pass_expiry` (body params: plate, date)
//   WHATSAPP_TEMPLATE_READY    default `vehicle_ready` (body params: plate)
//   WHATSAPP_TEMPLATE_RESERVATION default `reservation_confirmed`
//                              (body params: name, plate, until, lot)
//   WHATSAPP_TEMPLATE_REMINDER default `reservation_reminder`
//                              (body params: name, plate, until, lot)
//   WHATSAPP_TEMPLATE_CANCELLED default `reservation_cancelled`
//                              (body params: name, plate, lot)
//   WHATSAPP_TEMPLATE_WAITLIST_OFFER default `waitlist_offer`
//                              (body params: name, plate, deadline, lot, code)
//   WHATSAPP_TEMPLATE_PASS_RENEWAL default `pass_renewal_link`
//                              (body params: name, plate, date, amount;
//                               URL button parameter: the renewal token)
//
// Meta only accepts business-initiated messages as approved templates, so the
// queue stores a template name + positional parameters (never free text).

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const TOKEN = Deno.env.get('WHATSAPP_TOKEN') ?? ''
const PHONE_ID = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID') ?? ''
const API_VERSION = Deno.env.get('WHATSAPP_API_VERSION') ?? 'v21.0'
const TEMPLATES: Record<string, string> = {
  receipt: Deno.env.get('WHATSAPP_TEMPLATE_RECEIPT') ?? 'receipt',
  pass_expiry: Deno.env.get('WHATSAPP_TEMPLATE_PASS') ?? 'pass_expiry',
  vehicle_ready: Deno.env.get('WHATSAPP_TEMPLATE_READY') ?? 'vehicle_ready',
  reservation_confirmed:
    Deno.env.get('WHATSAPP_TEMPLATE_RESERVATION') ?? 'reservation_confirmed',
  reservation_reminder:
    Deno.env.get('WHATSAPP_TEMPLATE_REMINDER') ?? 'reservation_reminder',
  reservation_cancelled:
    Deno.env.get('WHATSAPP_TEMPLATE_CANCELLED') ?? 'reservation_cancelled',
  waitlist_offer:
    Deno.env.get('WHATSAPP_TEMPLATE_WAITLIST_OFFER') ?? 'waitlist_offer',
  pass_renewal_link:
    Deno.env.get('WHATSAPP_TEMPLATE_PASS_RENEWAL') ?? 'pass_renewal_link',
}

export type PendingMessage = {
  id: number
  to_phone: string
  template: string
  language: string
  params: string[]
  attempts: number
  button_param?: string | null
}

// Exported for the tests: the payload (and the URL button) is pure data.
export function buildMessagePayload(
  message: PendingMessage,
  templates: Record<string, string> = TEMPLATES,
): { payload?: Record<string, unknown>; error?: string } {
  const template = templates[message.template]
  if (!template) {
    return { error: `Unknown template: ${message.template}` }
  }
  const components: Record<string, unknown>[] = [
    {
      type: 'body',
      parameters: (message.params ?? []).map((text) => ({
        type: 'text',
        text: String(text),
      })),
    },
  ]
  const button = (message.button_param ?? '').trim()
  if (button) {
    // The fixed base URL lives in the approved Meta template; the parameter
    // is only the token after it.
    components.push({
      type: 'button',
      sub_type: 'url',
      index: '0',
      parameters: [{ type: 'text', text: button }],
    })
  }
  return {
    payload: {
      messaging_product: 'whatsapp',
      to: message.to_phone,
      type: 'template',
      template: {
        name: template,
        language: { code: message.language || 'es' },
        components,
      },
    },
  }
}

const jsonHeaders = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
}

async function rest(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: { ...jsonHeaders, ...(init.headers ?? {}) },
  })
  const text = await response.text()
  return { response, body: text ? JSON.parse(text) : null }
}

async function send(message: PendingMessage): Promise<{ ok: boolean; error?: string }> {
  const { payload, error } = buildMessagePayload(message)
  if (!payload) {
    return { ok: false, error }
  }
  const response = await fetch(
    `https://graph.facebook.com/${API_VERSION}/${PHONE_ID}/messages`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    },
  )
  if (response.ok) return { ok: true }
  const body = await response.text()
  console.error(`WhatsApp send failed (${response.status}): ${body}`)
  return { ok: false, error: `${response.status}: ${body.slice(0, 300)}` }
}

if (import.meta.main) Deno.serve(async (req) => {
  const started = Date.now()
  const done = (body: Record<string, unknown>, status = 200) => {
    console.log(
      JSON.stringify({
        fn: 'whatsapp-dispatch',
        status,
        ms: Date.now() - started,
        ...body,
      }),
    )
    return new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if (req.method !== 'POST') return done({ message: 'Method not allowed' }, 405)
  if (req.headers.get('authorization') !== `Bearer ${SERVICE_KEY}`) {
    return done({ message: 'Forbidden' }, 403)
  }
  if (!TOKEN || !PHONE_ID) {
    return done({ configured: false, sent: 0, failed: 0 })
  }

  const { response, body } = await rest(
    'whatsapp_messages?status=eq.pending&attempts=lt.3' +
      '&select=id,to_phone,template,language,params,button_param,attempts' +
      '&order=created_at&limit=50',
  )
  if (!response.ok || !Array.isArray(body)) {
    return done({ configured: true, error: 'Could not read the queue' }, 500)
  }
  const pending = body as PendingMessage[]
  if (pending.length === 0) {
    return done({ configured: true, sent: 0, failed: 0, pending: 0 })
  }

  let sent = 0
  let failed = 0
  for (const message of pending) {
    const result = await send(message)
    if (result.ok) {
      sent++
      await rest(`whatsapp_messages?id=eq.${message.id}`, {
        method: 'PATCH',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({ status: 'sent', sent_at: new Date().toISOString() }),
      })
      continue
    }
    failed++
    const attempts = message.attempts + 1
    await rest(`whatsapp_messages?id=eq.${message.id}`, {
      method: 'PATCH',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({
        attempts,
        status: attempts >= 3 ? 'failed' : 'pending',
        error: result.error ?? 'unknown',
      }),
    })
  }

  return done({ configured: true, sent, failed, pending: pending.length })
})
