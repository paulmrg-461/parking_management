// Payment gateway port. The SQL side never names a gateway (`payment_intents
// .gateway` is data); the Edge Functions talk to this interface only, so a
// second provider is an adapter, not a migration.

export type GatewayStatus =
  | 'APPROVED'
  | 'DECLINED'
  | 'VOIDED'
  | 'ERROR'
  | 'PENDING'

export type GatewayEvent = {
  transactionId: string
  reference: string
  status: GatewayStatus
  /** Amount in the lot currency's major unit (COP pesos, USD cents). */
  amount: number
  currency: string
  method: string
  occurredAt: string
  raw: unknown
}

export type CheckoutRequest = {
  reference: string
  amount: number
  currency: string
  redirectUrl: string
  expiresAt: string
}

export type CheckoutSession = { checkoutUrl: string }

export interface PaymentGateway {
  readonly name: string
  isConfigured(): boolean
  createCheckout(input: CheckoutRequest): Promise<CheckoutSession>
  /** `null` means the signature did not verify (never trust the body). */
  verifyEvent(rawBody: string, headers: Headers): Promise<GatewayEvent | null>
  findByReference(reference: string): Promise<GatewayEvent[]>
}
