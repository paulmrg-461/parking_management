// Wompi adapter. Every assumed detail of the provider API lives here, marked
// `ASSUMPTION`, so a change in their contract never reaches SQL or Flutter.
// Env is read on every call (not at import time) so the function can start
// before the secrets exist and the tests can stub them.

import type {
  CheckoutRequest,
  CheckoutSession,
  GatewayEvent,
  GatewayStatus,
  PaymentGateway,
} from './payment_gateway.ts'

// ASSUMPTION: confirm with the Wompi docs before go-live.
const DEFAULT_SANDBOX_API = 'https://sandbox.wompi.co/v1'
const DEFAULT_PRODUCTION_API = 'https://production.wompi.co/v1'
const DEFAULT_CHECKOUT_URL = 'https://checkout.wompi.co/p/'
// ASSUMPTION: Wompi signs the checkout as SHA-256(reference + amount_in_cents +
// currency + integrity secret).
const CHECKOUT_SIGNATURE_ORDER = ['reference', 'amountInCents', 'currency'] as const

const env = (name: string): string => Deno.env.get(name) ?? ''

const apiUrl = (): string =>
  env('WOMPI_API_URL') ||
  (env('WOMPI_ENV') === 'production' ? DEFAULT_PRODUCTION_API : DEFAULT_SANDBOX_API)

const checkoutBase = (): string => env('WOMPI_CHECKOUT_URL') || DEFAULT_CHECKOUT_URL

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(input),
  )
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

// Constant-time comparison: a timing oracle on the checksum is a forgery tool.
export function safeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false
  let diff = 0
  for (let index = 0; index < left.length; index += 1) {
    diff |= left.charCodeAt(index) ^ right.charCodeAt(index)
  }
  return diff === 0
}

// `properties` are dot paths relative to the payload's `data` object.
function propertyAt(source: unknown, path: string): string {
  let current: unknown = source
  for (const part of path.split('.')) {
    if (current === null || typeof current !== 'object') return ''
    current = (current as Record<string, unknown>)[part]
  }
  return current === null || current === undefined ? '' : String(current)
}

function statusOf(value: unknown): GatewayStatus {
  const status = String(value ?? '').toUpperCase()
  if (
    status === 'APPROVED' || status === 'DECLINED' || status === 'VOIDED' ||
    status === 'ERROR' || status === 'PENDING'
  ) {
    return status
  }
  return 'ERROR'
}

function mapTransaction(transaction: Record<string, unknown>): GatewayEvent {
  const cents = Number(transaction.amount_in_cents)
  return {
    transactionId: String(transaction.id ?? ''),
    reference: String(transaction.reference ?? ''),
    status: statusOf(transaction.status),
    // ASSUMPTION: COP has no minor-unit decimals in the app; a value that is
    // not divisible by 100 becomes -1 so the RPC records a mismatch instead of
    // silently rounding money.
    amount: Number.isFinite(cents) && cents % 100 === 0 ? cents / 100 : -1,
    currency: String(transaction.currency ?? ''),
    method: String(
      transaction.payment_method_type ??
        (transaction.payment_method as { type?: unknown } | undefined)?.type ??
        '',
    ),
    occurredAt: String(
      transaction.finalized_at ?? transaction.created_at ?? '',
    ),
    raw: transaction,
  }
}

export class WompiGateway implements PaymentGateway {
  readonly name = 'wompi'

  isConfigured(): boolean {
    return env('WOMPI_PUBLIC_KEY') !== '' &&
      env('WOMPI_PRIVATE_KEY') !== '' &&
      env('WOMPI_INTEGRITY_SECRET') !== '' &&
      env('WOMPI_EVENTS_SECRET') !== ''
  }

  async createCheckout(input: CheckoutRequest): Promise<CheckoutSession> {
    const publicKey = env('WOMPI_PUBLIC_KEY')
    const integrity = env('WOMPI_INTEGRITY_SECRET')
    if (!publicKey || !integrity) {
      throw new Error('PaymentsNotConfiguredError')
    }
    // ASSUMPTION: `amount_in_cents` is the major unit x 100 (COP pesos).
    const amountInCents = Math.round(input.amount * 100)
    const values: Record<string, string | number> = {
      reference: input.reference,
      amountInCents,
      currency: input.currency,
    }
    const signature = await sha256Hex(
      CHECKOUT_SIGNATURE_ORDER.map((key) => String(values[key])).join('') +
        integrity,
    )

    const url = new URL(checkoutBase())
    url.searchParams.set('public-key', publicKey)
    url.searchParams.set('currency', input.currency)
    url.searchParams.set('amount-in-cents', String(amountInCents))
    url.searchParams.set('reference', input.reference)
    url.searchParams.set('redirect-url', input.redirectUrl)
    url.searchParams.set('signature:integrity', signature)
    // ASSUMPTION: the Web Checkout has no expiry parameter; `expiresAt` is the
    // intent's own deadline and the page stops polling after it.
    return { checkoutUrl: url.toString() }
  }

  async verifyEvent(
    rawBody: string,
    headers: Headers,
  ): Promise<GatewayEvent | null> {
    const secret = env('WOMPI_EVENTS_SECRET')
    if (!secret) return null

    let body: Record<string, unknown> | null = null
    try {
      body = JSON.parse(rawBody) as Record<string, unknown>
    } catch (_) {
      return null
    }
    const signature = body?.signature as
      | { properties?: unknown; checksum?: unknown }
      | undefined
    if (
      !signature || !Array.isArray(signature.properties) ||
      typeof signature.checksum !== 'string'
    ) {
      return null
    }
    const timestamp = body?.timestamp
    if (timestamp === null || timestamp === undefined) return null

    // ASSUMPTION: checksum = SHA-256(concat(properties, in order) + timestamp +
    // events secret), hex encoded.
    const concatenated = signature.properties
      .map((path) => propertyAt(body?.data, String(path)))
      .join('')
    const expected = await sha256Hex(`${concatenated}${timestamp}${secret}`)
    const received = signature.checksum.toLowerCase()
    if (!safeEqual(expected, received)) return null

    const headerChecksum = headers.get('X-Event-Checksum')
    if (headerChecksum && !safeEqual(headerChecksum.toLowerCase(), received)) {
      return null
    }

    const transaction = (body?.data as { transaction?: unknown } | undefined)
      ?.transaction
    if (!transaction || typeof transaction !== 'object') return null
    return mapTransaction(transaction as Record<string, unknown>)
  }

  async findByReference(reference: string): Promise<GatewayEvent[]> {
    const privateKey = env('WOMPI_PRIVATE_KEY')
    if (!privateKey) throw new Error('PaymentsNotConfiguredError')

    // ASSUMPTION: GET {api}/transactions?reference=<reference> with the private
    // key answers `{data: [transaction, ...]}`.
    const url = new URL(`${apiUrl()}/transactions`)
    url.searchParams.set('reference', reference)
    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${privateKey}` },
    })
    if (!response.ok) return []
    const body = await response.json() as { data?: unknown }
    const rows = Array.isArray(body?.data) ? body.data : []
    return rows
      .filter((row): row is Record<string, unknown> =>
        row !== null && typeof row === 'object'
      )
      .map(mapTransaction)
  }
}
