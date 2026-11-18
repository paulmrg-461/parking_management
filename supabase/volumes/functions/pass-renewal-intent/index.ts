// Creates a payment intent for a monthly-pass renewal offer.
//
// The URL is opened from a WhatsApp button: the 48-hex token is the access
// key and the amount/period come from `pass_renewal_offers` server-side. The
// browser never sees a gateway key; the RPC is service-role only.
//
// Required env: the same Wompi keys and PAYMENT_REDIRECT_BASE_URL as
// `payment-intent`. Without them the function answers 503 and no DB call is
// made.

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

const TOKEN_PATTERN = /^[0-9a-f]{48}$/i

const STATUS_BY_ERROR: Record<string, number> = {
  InvalidLinkError: 400,
  PassRenewalNotFoundError: 404,
  PassRenewalPaidError: 409,
  PassRenewalExpiredError: 409,
  OnlinePaymentsDisabledError: 409,
  AmountTooLowError: 422,
  PaymentThrottledError: 429,
  PaymentsNotConfiguredError: 503,
}

export type PassRenewalIntentDeps = {
  gateway: PaymentGateway
  redirectBase: () => string
  rpc: (name: string, params: Record<string, unknown>) => Promise<RpcResult>
}

function defaultDeps(): PassRenewalIntentDeps {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  return {
    gateway: new WompiGateway(),
    redirectBase: () => Deno.env.get('PAYMENT_REDIRECT_BASE_URL') ?? '',
    rpc: (name, params) => serviceRpc(supabaseUrl, serviceKey, name, params),
  }
}

type Body = { token?: unknown }

export async function handle(
  req: Request,
  deps: PassRenewalIntentDeps = defaultDeps(),
): Promise<Response> {
  const startedAt = Date.now()
  const done = (
    body: Record<string, unknown>,
    status = 200,
  ) => {
    logLine('pass-renewal-intent', startedAt, status, {
      outcome: status === 200 ? 'created' : body.message,
    })
    return json(body, status)
  }

  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return done({ message: 'Method not allowed' }, 405)

  if (!deps.gateway.isConfigured() || deps.redirectBase() === '') {
    return done({ message: 'PaymentsNotConfiguredError' }, 503)
  }

  const body = await req.json().catch(() => null) as Body | null
  const token = typeof body?.token === 'string' ? body.token.trim() : ''
  if (!TOKEN_PATTERN.test(token)) {
    return done({ message: 'InvalidLinkError' }, 400)
  }

  const created = await deps.rpc('create_pass_renewal_intent', {
    p_token: token,
  })
  if (!created.ok) {
    const name = errorName(created.body) ?? 'PassRenewalNotFoundError'
    return done({ message: name }, STATUS_BY_ERROR[name] ?? 400)
  }

  const intent = created.body as {
    intent_id: number
    reference: string
    amount: number
    currency: string
    expires_at: string
  }

  try {
    const redirect = `${deps.redirectBase().replace(/\/+$/, '')}/renew` +
      `?t=${encodeURIComponent(token)}`
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
    })
  } catch (_) {
    return done({ message: 'PaymentsNotConfiguredError' }, 503)
  }
}

if (import.meta.main) Deno.serve((req) => handle(req))
