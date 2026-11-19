// Tests for the pass-renewal-intent Edge Function (mock gateway + PostgREST).

import { assert, assertEquals } from 'jsr:@std/assert@^1'
import type { PaymentGateway } from '../_shared/payment_gateway.ts'
import { handle, type PassRenewalIntentDeps } from './index.ts'

const TOKEN = 'a'.repeat(48)

type Recorded = { name: string; params: Record<string, unknown> }

function gateway(configured = true): PaymentGateway {
  return {
    name: 'wompi',
    isConfigured: () => configured,
    createCheckout: (input) =>
      Promise.resolve({
        checkoutUrl: `https://checkout.test/p/?reference=${input.reference}` +
          `&redirect=${encodeURIComponent(input.redirectUrl)}`,
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
): PassRenewalIntentDeps {
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
            intent_id: 12,
            reference: 'PM-1A2B3C4D5E6F',
            amount: 80000,
            currency: 'COP',
            status: 'pending',
            expires_at: '2026-11-17T12:30:00.000Z',
          },
        },
      )
    },
  }
}

const post = (body: unknown) =>
  new Request('https://fn.test/pass-renewal-intent', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })

Deno.test('pass-renewal-intent valid token returns checkout_url', async () => {
  const records: Recorded[] = []
  const response = await handle(post({ token: TOKEN }), deps({ records }))
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.intent_id, 12)
  assertEquals(body.amount, 80000)
  assert(body.checkout_url.includes('/renew?t=') || body.checkout_url.includes('%2Frenew'))
  assertEquals(records.length, 1)
  assertEquals(records[0].name, 'create_pass_renewal_intent')
  assertEquals(records[0].params.p_token, TOKEN)
})

Deno.test('pass-renewal-intent malformed token -> 400', async () => {
  for (const body of [{ token: 'short' }, { token: 'z'.repeat(48) }, {}, { token: 12 }]) {
    const response = await handle(post(body), deps())
    assertEquals(response.status, 400)
    assertEquals((await response.json()).message, 'InvalidLinkError')
  }
})

Deno.test('pass-renewal-intent RPC error maps its status', async () => {
  const cases: Array<[string, number]> = [
    ['PassRenewalNotFoundError', 404],
    ['PassRenewalPaidError', 409],
    ['PassRenewalExpiredError', 409],
    ['OnlinePaymentsDisabledError', 409],
    ['AmountTooLowError', 422],
    ['PaymentThrottledError', 429],
  ]
  for (const [name, status] of cases) {
    const response = await handle(
      post({ token: TOKEN }),
      deps({ rpcResult: { ok: false, status: 400, body: { message: name } } }),
    )
    assertEquals(response.status, status, name)
    assertEquals((await response.json()).message, name)
  }
})

Deno.test('pass-renewal-intent missing keys -> 503 without a DB call', async () => {
  const records: Recorded[] = []
  const response = await handle(
    post({ token: TOKEN }),
    deps({ configured: false, records }),
  )
  assertEquals(response.status, 503)
  assertEquals((await response.json()).message, 'PaymentsNotConfiguredError')
  assertEquals(records.length, 0)
})

Deno.test('pass-renewal-intent never echoes a secret', async () => {
  const response = await handle(post({ token: TOKEN }), deps())
  const text = JSON.stringify(await response.json())
  assert(!text.includes('WOMPI'))
  assert(!text.includes('secret'))
  assert(!text.includes('prv_'))
})
