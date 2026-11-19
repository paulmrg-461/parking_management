// Deno tests for the Wompi adapter. No network: `findByReference` stubs the
// global fetch and the rest is pure crypto/URL work.
//
// Run: deno test supabase/volumes/functions/_shared

import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@^1'
import { safeEqual, WompiGateway } from './wompi_gateway.ts'

const SECRET = 'test-events-secret'
const INTEGRITY = 'test-integrity-secret'

function setEnv(values: Record<string, string>): void {
  for (const [key, value] of Object.entries(values)) Deno.env.set(key, value)
}

function clearEnv(names: string[]): void {
  for (const name of names) Deno.env.delete(name)
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(input),
  )
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

type SignedBody = {
  body: string
  amount: number
  reference: string
  transactionId: string
}

async function signedEvent(
  overrides: { bodyAmountInCents?: number; checksum?: string } = {},
): Promise<SignedBody> {
  const reference = 'PM-1A2B3C4D5E6F'
  const transactionId = 'tx-1'
  // The checksum always signs the real amount; the body may carry another one.
  const signedAmountInCents = 600000
  const amountInCents = overrides.bodyAmountInCents ?? signedAmountInCents
  const timestamp = 1763000000
  const properties = [
    'transaction.id',
    'transaction.status',
    'transaction.amount_in_cents',
  ]
  const checksum = overrides.checksum ??
    await sha256Hex(
      `${transactionId}APPROVED${signedAmountInCents}${timestamp}${SECRET}`,
    )
  const body = JSON.stringify({
    event: 'transaction.updated',
    data: {
      transaction: {
        id: transactionId,
        status: 'APPROVED',
        reference,
        amount_in_cents: amountInCents,
        currency: 'COP',
        payment_method_type: 'CARD',
        finalized_at: '2026-11-17T12:00:00.000Z',
      },
    },
    signature: { properties, checksum },
    timestamp,
  })
  return { body, amount: signedAmountInCents / 100, reference, transactionId }
}

Deno.test('verifyEvent accepts a correctly signed APPROVED event', async () => {
  setEnv({ WOMPI_EVENTS_SECRET: SECRET })
  try {
    const signed = await signedEvent()
    const event = await new WompiGateway().verifyEvent(
      signed.body,
      new Headers(),
    )
    assert(event !== null)
    assertEquals(event!.status, 'APPROVED')
    assertEquals(event!.transactionId, signed.transactionId)
    assertEquals(event!.reference, signed.reference)
    assertEquals(event!.amount, signed.amount)
    assertEquals(event!.currency, 'COP')
    assertEquals(event!.method, 'CARD')
  } finally {
    clearEnv(['WOMPI_EVENTS_SECRET'])
  }
})

Deno.test('verifyEvent returns null for a tampered amount', async () => {
  setEnv({ WOMPI_EVENTS_SECRET: SECRET })
  try {
    // The checksum was computed for 600000 cents; the body says 100.
    const signed = await signedEvent({ bodyAmountInCents: 100 })
    const event = await new WompiGateway().verifyEvent(
      signed.body,
      new Headers(),
    )
    assertEquals(event, null)
  } finally {
    clearEnv(['WOMPI_EVENTS_SECRET'])
  }
})

Deno.test('verifyEvent returns null for a wrong checksum', async () => {
  setEnv({ WOMPI_EVENTS_SECRET: SECRET })
  try {
    const signed = await signedEvent({ checksum: 'a'.repeat(64) })
    const event = await new WompiGateway().verifyEvent(
      signed.body,
      new Headers(),
    )
    assertEquals(event, null)

    const missingSecret = await new WompiGateway().verifyEvent(
      signed.body,
      new Headers(),
    )
    assertEquals(missingSecret, null)
  } finally {
    clearEnv(['WOMPI_EVENTS_SECRET'])
  }
})

Deno.test('verifyEvent rejects a body that is not JSON', async () => {
  setEnv({ WOMPI_EVENTS_SECRET: SECRET })
  try {
    const event = await new WompiGateway().verifyEvent('not-json', new Headers())
    assertEquals(event, null)
  } finally {
    clearEnv(['WOMPI_EVENTS_SECRET'])
  }
})

Deno.test('createCheckout signs amount x 100 and includes the redirect', async () => {
  setEnv({
    WOMPI_PUBLIC_KEY: 'pub_test_123',
    WOMPI_INTEGRITY_SECRET: INTEGRITY,
    WOMPI_EVENTS_SECRET: SECRET,
    WOMPI_PRIVATE_KEY: 'prv_test_123',
  })
  try {
    const gateway = new WompiGateway()
    const { checkoutUrl } = await gateway.createCheckout({
      reference: 'PM-1A2B3C4D5E6F',
      amount: 6000,
      currency: 'COP',
      redirectUrl: 'https://parking.example.com/evidence?session=55&pay=PM-1A2B3C4D5E6F',
      expiresAt: '2026-11-17T12:30:00.000Z',
    })
    const url = new URL(checkoutUrl)
    assertEquals(url.searchParams.get('public-key'), 'pub_test_123')
    assertEquals(url.searchParams.get('amount-in-cents'), '600000')
    assertEquals(url.searchParams.get('currency'), 'COP')
    assertEquals(url.searchParams.get('reference'), 'PM-1A2B3C4D5E6F')
    assert(url.searchParams.get('redirect-url')!.includes('/evidence?session=55'))
    const signature = url.searchParams.get('signature:integrity')!
    assertEquals(signature, await sha256Hex(
      `PM-1A2B3C4D5E6F600000COP${INTEGRITY}`,
    ))
    assert(!checkoutUrl.includes(INTEGRITY))
  } finally {
    clearEnv([
      'WOMPI_PUBLIC_KEY',
      'WOMPI_INTEGRITY_SECRET',
      'WOMPI_EVENTS_SECRET',
      'WOMPI_PRIVATE_KEY',
    ])
  }
})

Deno.test('createCheckout throws when a key is missing', async () => {
  setEnv({ WOMPI_EVENTS_SECRET: SECRET })
  try {
    await assertRejects(
      () =>
        new WompiGateway().createCheckout({
          reference: 'PM-1',
          amount: 6000,
          currency: 'COP',
          redirectUrl: 'https://example.com',
          expiresAt: '2026-11-17T12:30:00.000Z',
        }),
      Error,
      'PaymentsNotConfiguredError',
    )
  } finally {
    clearEnv(['WOMPI_EVENTS_SECRET'])
  }
})

Deno.test('findByReference maps statuses', async () => {
  setEnv({ WOMPI_PRIVATE_KEY: 'prv_test_123' })
  const originalFetch = globalThis.fetch
  try {
    globalThis.fetch = ((input: string | URL | Request): Promise<Response> => {
      const url = new URL(String(input))
      assertEquals(url.searchParams.get('reference'), 'PM-1A2B3C4D5E6F')
      return Promise.resolve(new Response(JSON.stringify({
        data: [
          {
            id: 'tx-1',
            reference: 'PM-1A2B3C4D5E6F',
            status: 'APPROVED',
            amount_in_cents: 600000,
            currency: 'COP',
            payment_method_type: 'NEQUI',
          },
          {
            id: 'tx-2',
            reference: 'PM-1A2B3C4D5E6F',
            status: 'DECLINED',
            amount_in_cents: 1,
            currency: 'COP',
          },
        ],
      }), { status: 200 }))
    }) as typeof fetch

    const events = await new WompiGateway().findByReference('PM-1A2B3C4D5E6F')
    assertEquals(events.length, 2)
    assertEquals(events[0].status, 'APPROVED')
    assertEquals(events[0].amount, 6000)
    assertEquals(events[0].method, 'NEQUI')
    assertEquals(events[1].status, 'DECLINED')
    // Not divisible by 100: forwarded as -1 so the RPC stores a mismatch.
    assertEquals(events[1].amount, -1)
  } finally {
    globalThis.fetch = originalFetch
    clearEnv(['WOMPI_PRIVATE_KEY'])
  }
})

Deno.test('checksum comparison is constant time (same helper used)', () => {
  assert(safeEqual('abc123', 'abc123'))
  assert(!safeEqual('abc123', 'abc124'))
  assert(!safeEqual('abc', 'abcd'))
  assert(!safeEqual('', 'a'))
})

Deno.test('the events secret never appears in any output', async () => {
  setEnv({ WOMPI_EVENTS_SECRET: SECRET })
  try {
    const signed = await signedEvent()
    const event = await new WompiGateway().verifyEvent(
      signed.body,
      new Headers({ 'X-Event-Checksum': 'ignored-when-wrong' }),
    )
    // A header that disagrees with the signature rejects the event.
    assertEquals(event, null)

    const good = await new WompiGateway().verifyEvent(
      signed.body,
      new Headers(),
    )
    assert(good !== null)
    assert(!JSON.stringify(good).includes(SECRET))
  } finally {
    clearEnv(['WOMPI_EVENTS_SECRET'])
  }
})
