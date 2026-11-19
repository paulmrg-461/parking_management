// Wompi webhook. The checksum is the only authentication: this route must stay
// reachable without a JWT and from the public internet, so `FUNCTIONS_VERIFY_JWT`
// must remain false. The redirect page never trusts `?id=`; it polls
// `payment_intent_status`.
//
// Duplicates and unknown references answer 200 (Wompi stops retrying), a bad
// checksum is 401 (nothing is written) and an RPC failure is 500 (Wompi
// retries).

import type { PaymentGateway } from '../_shared/payment_gateway.ts'
import {
  errorName,
  json,
  logLine,
  type RpcResult,
  serviceRpc,
} from '../_shared/http.ts'
import { WompiGateway } from '../_shared/wompi_gateway.ts'

export type PaymentWebhookDeps = {
  gateway: PaymentGateway
  configured: () => boolean
  rpc: (name: string, params: Record<string, unknown>) => Promise<RpcResult>
}

function defaultDeps(): PaymentWebhookDeps {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  return {
    gateway: new WompiGateway(),
    configured: () => (Deno.env.get('WOMPI_EVENTS_SECRET') ?? '') !== '',
    rpc: (name, params) => serviceRpc(supabaseUrl, serviceKey, name, params),
  }
}

export async function handle(
  req: Request,
  deps: PaymentWebhookDeps = defaultDeps(),
): Promise<Response> {
  const startedAt = Date.now()
  const done = (body: Record<string, unknown>, status = 200) => {
    logLine('payment-webhook', startedAt, status, {
      outcome: body.outcome ?? body.message ?? (body.ignored ? 'ignored' : 'ok'),
    })
    return json(body, status)
  }

  if (req.method !== 'POST') {
    return done({ message: 'Method not allowed' }, 405)
  }
  if (!deps.configured()) return done({ configured: false }, 503)

  // Read the raw body exactly once: the checksum is computed over it.
  const raw = await req.text()
  let parsed: { event?: unknown } | null = null
  try {
    parsed = JSON.parse(raw) as { event?: unknown }
  } catch (_) {
    return done({ message: 'InvalidSignatureError' }, 401)
  }
  if (parsed?.event !== 'transaction.updated') {
    return done({ ignored: true })
  }

  const event = await deps.gateway.verifyEvent(raw, req.headers)
  if (event === null) {
    return done({ message: 'InvalidSignatureError' }, 401)
  }
  if (event.status === 'PENDING') {
    return done({ ignored: true })
  }

  const applied = await deps.rpc('apply_payment_event', {
    p_gateway: deps.gateway.name,
    p_event: {
      transaction_id: event.transactionId,
      reference: event.reference,
      status: event.status,
      amount: event.amount,
      currency: event.currency,
      method: event.method,
      occurred_at: event.occurredAt,
      raw: event.raw,
    },
  })
  if (!applied.ok) {
    // Surface the typed name for the logs, hide the internals from Wompi.
    const name = errorName(applied.body)
    console.error(JSON.stringify({
      fn: 'payment-webhook',
      rpc: 'apply_payment_event',
      status: applied.status,
      error: name,
    }))
    return done({ message: 'PaymentEventFailedError' }, 500)
  }

  const result = applied.body as { applied?: boolean; outcome?: string }
  return done({
    applied: result.applied === true,
    outcome: result.outcome ?? 'ignored',
  })
}

if (import.meta.main) Deno.serve((req) => handle(req))
