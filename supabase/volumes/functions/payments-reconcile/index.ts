// Reconciliation job: a lost webhook must not leave a paid customer unpaid.
// Service-role only (the job posts with the service key); it asks the gateway
// for every pending intent older than 10 minutes and feeds the answer through
// the same `apply_payment_event`, so the idempotency lives in one place.

import type { PaymentGateway } from '../_shared/payment_gateway.ts'
import {
  errorName,
  json,
  logLine,
  type RpcResult,
  serviceRpc,
} from '../_shared/http.ts'
import { WompiGateway } from '../_shared/wompi_gateway.ts'

export type ReconcileDeps = {
  gateway: PaymentGateway
  serviceKey: () => string
  rpc: (name: string, params: Record<string, unknown>) => Promise<RpcResult>
}

function defaultDeps(): ReconcileDeps {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  return {
    gateway: new WompiGateway(),
    serviceKey: () => serviceKey,
    rpc: (name, params) => serviceRpc(supabaseUrl, serviceKey, name, params),
  }
}

type PendingIntent = { id: number; reference: string; gateway: string; amount: number }

export async function handle(
  req: Request,
  deps: ReconcileDeps = defaultDeps(),
): Promise<Response> {
  const startedAt = Date.now()
  const done = (body: Record<string, unknown>, status = 200) => {
    logLine('payments-reconcile', startedAt, status, body)
    return json(body, status)
  }

  const authorization = req.headers.get('Authorization') ?? ''
  if (deps.serviceKey() === '' || authorization !== `Bearer ${deps.serviceKey()}`) {
    return done({ message: 'Forbidden' }, 403)
  }
  if (!deps.gateway.isConfigured()) {
    return done({ configured: false, checked: 0 })
  }

  const listed = await deps.rpc('list_reconcilable_payment_intents', {
    p_older_than_minutes: 10,
  })
  if (!listed.ok) {
    const name = errorName(listed.body)
    console.error(JSON.stringify({
      fn: 'payments-reconcile',
      rpc: 'list_reconcilable_payment_intents',
      status: listed.status,
      error: name,
    }))
    return done({ configured: true, checked: 0, applied: 0 }, 500)
  }

  const intents = Array.isArray(listed.body) ? listed.body as PendingIntent[] : []
  let applied = 0
  for (const intent of intents) {
    let events = []
    try {
      events = await deps.gateway.findByReference(intent.reference)
    } catch (_) {
      continue
    }
    for (const event of events) {
      if (event.status === 'PENDING') continue
      const result = await deps.rpc('apply_payment_event', {
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
      if (result.ok) {
        const body = result.body as { applied?: boolean }
        if (body.applied === true) applied += 1
      }
    }
  }

  return done({ configured: true, checked: intents.length, applied })
}

if (import.meta.main) Deno.serve((req) => handle(req))
