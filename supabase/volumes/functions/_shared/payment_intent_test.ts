// Tests for the payment-intent Edge Function (mock gateway + mock PostgREST).

import { assert, assertEquals } from 'jsr:@std/assert@^1'
import type { PaymentGateway } from './payment_gateway.ts'
import { handle, type PaymentIntentDeps } from '../payment-intent/index.ts'

type Recorded = { name: string; params: Record<string, unknown> }

function gateway(configured = true): PaymentGateway {
  return {
    name: 'wompi',
    isConfigured: () => configured,
    createCheckout: (input) =>
      Promise.resolve({
        checkoutUrl: `https://checkout.test/p/?reference=${input.reference}` +
          `&amount=${input.amount}&redirect=${encodeURIComponent(input.redirectUrl)}`,
      }),
    verifyEvent: () => Promise.resolve(null),
    findByReference: () => Promise.resolve([]),
  }
}

function deps(
  options: {
    configured?: boolean
    redirect?: string
    rpcResult?: { ok: boolean; status: number; body: unknown }
    records?: Recorded[]
  } = {},
): PaymentIntentDeps {
  const records = options.records ?? []
  return {
    gateway: gateway(options.configured ?? true),
    redirectBase: () => options.redirect ?? 'https://parking.test',
    rpc: (name, params) => {
      records.push({ name, params })
      return Promise.resolve(
        options.rpcResult ?? {
          ok: true,
          status: 200,
          body: {
            intent_id: 9,
            reference: 'PM-1A2B3C4D5E6F',
            amount: 6000,
            currency: 'COP',
            status: 'pending',
            expires_at: '2026-11-17T12:30:00.000Z',
            grace_minutes: 15,
          },
        },
      )
    },
  }
}

const post = (body: unknown) =>
  new Request('https://fn.test/payment-intent', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })

Deno.test('payment-intent valid body returns checkout_url', async () => {
  const records: Recorded[] = []
  const response = await handle(
    post({ session: 55, plate: 'ABC123' }),
    deps({ records }),
  )
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.intent_id, 9)
  assertEquals(body.reference, 'PM-1A2B3C4D5E6F')
  assertEquals(body.amount, 6000)
  assert(body.checkout_url.includes('PM-1A2B3C4D5E6F'))
  assert(body.checkout_url.includes('session%3D55') || body.checkout_url.includes('/evidence?session=55'))
  assertEquals(records.length, 1)
  assertEquals(records[0].name, 'create_session_payment_intent')
  assertEquals(records[0].params.p_session_id, 55)
  assertEquals(records[0].params.p_plate, 'ABC123')
})

Deno.test('payment-intent missing keys -> 503 and no DB call', async () => {
  const records: Recorded[] = []
  const response = await handle(
    post({ session: 55, plate: 'ABC123' }),
    deps({ configured: false, records }),
  )
  assertEquals(response.status, 503)
  const body = await response.json()
  assertEquals(body.message, 'PaymentsNotConfiguredError')
  assertEquals(records.length, 0)

  const noRedirect = await handle(
    post({ session: 55, plate: 'ABC123' }),
    deps({ redirect: '', records }),
  )
  assertEquals(noRedirect.status, 503)
  assertEquals(records.length, 0)
})

Deno.test('payment-intent RPC error name is passed through with its status', async () => {
  const cases: Array<[string, number]> = [
    ['SessionNotFoundError', 404],
    ['SessionAlreadyClosedError', 409],
    ['OnlinePaymentsDisabledError', 409],
    ['NothingToPayError', 409],
    ['AmountTooLowError', 422],
    ['PaymentThrottledError', 429],
  ]
  for (const [name, status] of cases) {
    const response = await handle(
      post({ session: 55, plate: 'ABC123' }),
      deps({ rpcResult: { ok: false, status: 400, body: { message: name } } }),
    )
    assertEquals(response.status, status, name)
    const body = await response.json()
    assertEquals(body.message, name)
  }
})

Deno.test('payment-intent invalid body -> 400 InvalidLinkError', async () => {
  for (const body of [null, {}, { session: 0, plate: 'ABC123' }, {
    session: 55,
    plate: 'ab',
  }, { session: '55', plate: 'ABC123' }]) {
    const response = await handle(post(body), deps())
    if (body === null) {
      // A body that is not JSON is also a bad link.
      assertEquals(response.status, 400)
      continue
    }
    assertEquals(response.status, 400)
    const parsed = await response.json()
    assertEquals(parsed.message, 'InvalidLinkError')
  }
})
