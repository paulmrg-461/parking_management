// Public booking behind a captcha: the customer page posts the form plus a
// Cloudflare Turnstile token here, this function verifies the token with the
// secret and only then creates the hold through
// `rpc/public_create_reservation_verified`, which is granted to the service
// role alone. A lot with `parking_settings.public_booking_captcha = true`
// refuses the anonymous RPC, so this is the only way in for that lot.
//
// Required env to enforce the captcha:
//   TURNSTILE_SECRET_KEY   secret key of the Turnstile widget
// Optional:
//   TURNSTILE_VERIFY_URL   override of the siteverify endpoint (tests)
//
// Without the secret the function is inert: it forwards the request to the
// anonymous RPC with the anon key and no extra privilege, so a lot that does
// not demand a captcha books exactly as before and one that does is refused by
// the database (`CaptchaRequiredError`). It never books unverified with the
// service role.
//
// The caller only needs the anon key. Customer data (name, phone) is never
// logged.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const SECRET = Deno.env.get('TURNSTILE_SECRET_KEY') ?? ''
const VERIFY_URL = Deno.env.get('TURNSTILE_VERIFY_URL') ??
  'https://challenges.cloudflare.com/turnstile/v0/siteverify'
const VERIFY_TIMEOUT_MS = 8000
const MAX_TOKEN_LENGTH = 2048

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type Booking = {
  lot_id?: unknown
  plate?: unknown
  category_id?: unknown
  until?: unknown
  name?: unknown
  phone?: unknown
  captcha_token?: unknown
}

type Verdict = 'ok' | 'expired' | 'failed' | 'unavailable'

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })

function clientIp(req: Request): string {
  const forwarded = req.headers.get('cf-connecting-ip') ??
    req.headers.get('x-forwarded-for') ?? ''
  return forwarded.split(',')[0].trim()
}

// Tokens are single use and live five minutes; Cloudflare answers
// `timeout-or-duplicate` for both, which the page treats as "solve it again".
async function verify(token: string, ip: string): Promise<Verdict> {
  const form = new URLSearchParams({ secret: SECRET, response: token })
  if (ip) form.set('remoteip', ip)
  try {
    const response = await fetch(VERIFY_URL, {
      method: 'POST',
      body: form,
      signal: AbortSignal.timeout(VERIFY_TIMEOUT_MS),
    })
    if (!response.ok) return 'unavailable'
    const body = await response.json() as {
      success?: boolean
      'error-codes'?: string[]
    }
    if (body.success === true) return 'ok'
    const codes = body['error-codes'] ?? []
    if (codes.includes('timeout-or-duplicate')) return 'expired'
    // A wrong secret is our misconfiguration, not the customer's failure.
    if (codes.some((code) => code.includes('input-secret'))) return 'unavailable'
    return 'failed'
  } catch (_) {
    return 'unavailable'
  }
}

async function book(rpc: string, key: string, booking: Booking) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: 'POST',
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      p_lot_id: booking.lot_id,
      p_plate: booking.plate,
      p_category_id: booking.category_id,
      p_until: booking.until,
      p_customer_name: booking.name,
      p_customer_phone: booking.phone,
    }),
  })
  const text = await response.text()
  let body: unknown = null
  try {
    body = text ? JSON.parse(text) : null
  } catch (_) {
    body = null
  }
  return { ok: response.ok, status: response.status, body }
}

// The RPC raises typed names (`BookingThrottledError`, `CategoryFullError`,
// ...) as the PostgREST message; the page localizes them, so they travel
// as-is. Anything else is reported without internals.
function refusal(status: number, body: unknown) {
  const message = (body as { message?: unknown } | null)?.message
  if (typeof message === 'string' && /^[A-Za-z]+Error$/.test(message)) {
    return {
      message,
      status: message === 'BookingThrottledError' ? 429 : 400,
    }
  }
  return { message: 'BookingUnavailableError', status: status >= 500 ? 503 : 400 }
}

Deno.serve(async (req) => {
  const started = Date.now()
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  let lot: unknown = null
  const done = (body: Record<string, unknown>, status = 200) => {
    console.log(JSON.stringify({
      fn: 'public-booking',
      status,
      ms: Date.now() - started,
      lot,
      captcha: SECRET !== '',
      outcome: status === 200 ? 'booked' : body.message,
    }))
    return json(body, status)
  }

  if (req.method !== 'POST') return done({ message: 'Method not allowed' }, 405)
  const booking = await req.json().catch(() => null) as Booking | null
  if (booking === null || typeof booking !== 'object') {
    return done({ message: 'InvalidDataError' }, 400)
  }
  lot = Number.isInteger(booking.lot_id) ? booking.lot_id : null

  let rpc = 'public_create_reservation'
  let key = ANON_KEY
  if (SECRET) {
    const token = typeof booking.captcha_token === 'string'
      ? booking.captcha_token.trim()
      : ''
    if (!token || token.length > MAX_TOKEN_LENGTH) {
      return done({ message: 'CaptchaRequiredError' }, 400)
    }
    const verdict = await verify(token, clientIp(req))
    if (verdict === 'expired') return done({ message: 'CaptchaExpiredError' }, 400)
    if (verdict === 'failed') return done({ message: 'CaptchaFailedError' }, 403)
    if (verdict === 'unavailable') {
      return done({ message: 'CaptchaUnavailableError' }, 503)
    }
    rpc = 'public_create_reservation_verified'
    key = SERVICE_KEY
  }

  const result = await book(rpc, key, booking)
  if (!result.ok) {
    const { message, status } = refusal(result.status, result.body)
    return done({ message }, status)
  }
  return done(result.body as Record<string, unknown>)
})
