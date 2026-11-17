// Creates a payment intent and returns the gateway checkout URL.
//
// The caller only needs the anon key (like `public-evidence`): the session id
// plus the plate are the access key, the amount is computed by the database
// (`create_session_payment_intent` -> `session_settlement`) and never sent by
// the browser. The RPC is granted to the service role alone.
//
// Required env: WOMPI_PUBLIC_KEY, WOMPI_PRIVATE_KEY, WOMPI_INTEGRITY_SECRET,
// WOMPI_EVENTS_SECRET, PAYMENT_REDIRECT_BASE_URL. Without them the function
// answers 503 and no DB call is made (the site behaves as today).

import type { PaymentGateway } from '../_shared/payment_gateway.ts'
import {
  CORS,
  errorName,
  json,
  logLine,
  type RpcResult,
  serviceRpc,
} from '../_shared/http.ts'
import { WompiGateway } from '../_shared/wompi_gateway.ts'

const STATUS_BY_ERROR: Record<string, number> = {
  InvalidLinkError: 400,
  SessionNotFoundError: 404,
  SessionAlreadyClosedError: 409,
  OnlinePaymentsDisabledError: 409,
  NothingToPayError: 409,
  AmountTooLowError: 422,
  PaymentThrottledError: 429,
  PaymentsNotConfiguredError: 503,
}

export type PaymentIntentDeps = {
  gateway: PaymentGateway
  redirectBase: () => string
  rpc: (name: string, params: Record<string, unknown>) => Promise<RpcResult>
}

function defaultDeps(): PaymentIntentDeps {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  return {
    gateway: new WompiGateway(),
    redirectBase: () => Deno.env.get('PAYMENT_REDIRECT_BASE_URL') ?? '',
    rpc: (name, params) => serviceRpc(supabaseUrl, serviceKey, name, params),
  }
}

type Body = { session?: unknown; plate?: unknown }

export async function handle(
  req: Request,
  deps: PaymentIntentDeps = defaultDeps(),
): Promise<Response> {
  const startedAt = Date.now()
  const done = (
    body: Record<string, unknown>,
    status = 200,
    extra: Record<string, unknown> = {},
  ) => {
    logLine('payment-intent', startedAt, status, {
      outcome: status === 200 ? 'created' : body.message,
      ...extra,
    })
    return json(body, status)
  }

  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return done({ message: 'Method not allowed' }, 405)

  if (!deps.gateway.isConfigured() || deps.redirectBase() === '') {
    // Never call the database when the gateway is inert.
    return done({ message: 'PaymentsNotConfiguredError' }, 503)
  }

  const body = await req.json().catch(() => null) as Body | null
  const sessionId = body?.session
  const plate = body?.plate
  if (
    !Number.isInteger(sessionId) || (sessionId as number) <= 0 ||
    typeof plate !== 'string' || plate.trim().length < 3
  ) {
    return done({ message: 'InvalidLinkError' }, 400)
  }

  const created = await deps.rpc('create_session_payment_intent', {
    p_session_id: sessionId,
    p_plate: plate,
  })
  if (!created.ok) {
    const name = errorName(created.body) ?? 'PaymentsNotConfiguredError'
    return done({ message: name }, STATUS_BY_ERROR[name] ?? 400)
  }

  const intent = created.body as {
    intent_id: number
    reference: string
    amount: number
    currency: string
    expires_at: string
    grace_minutes: number
  }

  try {
    const redirect = `${deps.redirectBase().replace(/\/+$/, '')}/evidence` +
      `?session=${sessionId}&pay=${encodeURIComponent(intent.reference)}`
    const checkout = await deps.gateway.createCheckout({
      reference: intent.reference,
      amount: intent.amount,
      currency: intent.currency,
      redirectUrl: redirect,
      expiresAt: intent.expires_at,
    })
    return done({
      intent_id: intent.intent_id,
      reference: intent.reference,
      amount: intent.amount,
      currency: intent.currency,
      checkout_url: checkout.checkoutUrl,
      expires_at: intent.expires_at,
      grace_minutes: intent.grace_minutes,
    }, 200, { session: sessionId })
  } catch (_) {
    return done({ message: 'PaymentsNotConfiguredError' }, 503)
  }
}

if (import.meta.main) Deno.serve((req) => handle(req))
