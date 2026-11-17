// Tests for the payments-reconcile Edge Function.

import { assertEquals } from 'jsr:@std/assert@^1'
import type { GatewayEvent, PaymentGateway } from './payment_gateway.ts'
import { handle, type ReconcileDeps } from '../payments-reconcile/index.ts'

type Recorded = { name: string; params: Record<string, unknown> }

const approved: GatewayEvent = {
  transactionId: 'tx-1',
  reference: 'PM-1A2B3C4D5E6F',
  status: 'APPROVED',
  amount: 6000,
  currency: 'COP',
  method: 'CARD',
  occurredAt: '2026-11-17T12:00:00.000Z',
  raw: {},
}

function gateway(options: { configured?: boolean; events?: GatewayEvent[] } = {}): PaymentGateway {
  return {
    name: 'wompi',
    isConfigured: () => options.configured ?? true,
    createCheckout: () => Promise.reject(new Error('not used')),
    verifyEvent: () => Promise.resolve(null),
    findByReference: () => Promise.resolve(options.events ?? [approved]),
  }
}

function deps(
  options: {
    configured?: boolean
    events?: GatewayEvent[]
    rpcResult?: { ok: boolean; status: number; body: unknown }
    records?: Recorded[]
  } = {},
): ReconcileDeps {
  const records = options.records ?? []
  return {
    gateway: gateway(options),
    serviceKey: () => 'service-key',
    rpc: (name, params) => {
      records.push({ name, params })
      if (name === 'list_reconcilable_payment_intents') {
        return Promise.resolve({
          ok: true,
          status: 200,
          body: [{
            id: 9,
            reference: 'PM-1A2B3C4D5E6F',
            gateway: 'wompi',
            amount: 6000,
          }],
        })
      }
      return Promise.resolve(
        options.rpcResult ??
          { ok: true, status: 200, body: { applied: true, outcome: 'applied' } },
      )
    },
  }
}

const post = (key = 'service-key') =>
  new Request('https://fn.test/payments-reconcile', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}` },
  })

Deno.test('payments-reconcile not service key -> 403', async () => {
  const records: Recorded[] = []
  const response = await handle(post('anon'), deps({ records }))
  assertEquals(response.status, 403)
  assertEquals(records.length, 0)
})

Deno.test('payments-reconcile no keys -> configured false', async () => {
  const records: Recorded[] = []
  const response = await handle(post(), deps({ configured: false, records }))
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.configured, false)
  assertEquals(body.checked, 0)
  assertEquals(records.length, 0)
})

Deno.test('payments-reconcile pending intent found approved is applied', async () => {
  const records: Recorded[] = []
  const response = await handle(post(), deps({ records }))
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.configured, true)
  assertEquals(body.checked, 1)
  assertEquals(body.applied, 1)
  const applied = records.filter((entry) => entry.name === 'apply_payment_event')
  assertEquals(applied.length, 1)
  const payload = applied[0].params.p_event as Record<string, unknown>
  assertEquals(payload.reference, 'PM-1A2B3C4D5E6F')
  assertEquals(payload.amount, 6000)
})
