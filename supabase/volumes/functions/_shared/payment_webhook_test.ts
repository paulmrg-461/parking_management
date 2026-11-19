// Tests for the payment-webhook Edge Function (mock gateway + mock PostgREST).

import { assertEquals } from 'jsr:@std/assert@^1'
import type { GatewayEvent, PaymentGateway } from './payment_gateway.ts'
import { handle, type PaymentWebhookDeps } from '../payment-webhook/index.ts'

type Recorded = { name: string; params: Record<string, unknown> }

const approved: GatewayEvent = {
  transactionId: 'tx-1',
  reference: 'PM-1A2B3C4D5E6F',
  status: 'APPROVED',
  amount: 6000,
  currency: 'COP',
  method: 'CARD',
  occurredAt: '2026-11-17T12:00:00.000Z',
  raw: { id: 'tx-1' },
}

function gateway(
  event: GatewayEvent | null,
  signatureOk = true,
): PaymentGateway {
  return {
    name: 'wompi',
    isConfigured: () => true,
    createCheckout: () => Promise.reject(new Error('not used')),
    verifyEvent: () => Promise.resolve(signatureOk ? event : null),
    findByReference: () => Promise.resolve([]),
  }
}

function deps(
  options: {
    event?: GatewayEvent | null
    configured?: boolean
    rpcResult?: { ok: boolean; status: number; body: unknown }
    records?: Recorded[]
  } = {},
): PaymentWebhookDeps {
  const records = options.records ?? []
  return {
    gateway: gateway(options.event ?? approved),
    configured: () => options.configured ?? true,
    rpc: (name, params) => {
      records.push({ name, params })
      return Promise.resolve(
        options.rpcResult ?? {
          ok: true,
          status: 200,
          body: { applied: true, duplicate: false, outcome: 'applied' },
        },
      )
    },
  }
}

const post = (body: unknown) =>
  new Request('https://fn.test/payment-webhook', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })

const transactionEvent = {
  event: 'transaction.updated',
  data: { transaction: { id: 'tx-1', status: 'APPROVED' } },
  signature: { properties: [], checksum: 'x' },
  timestamp: 1763000000,
}

Deno.test('payment-webhook valid event calls apply_payment_event once', async () => {
  const records: Recorded[] = []
  const response = await handle(post(transactionEvent), deps({ records }))
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.applied, true)
  assertEquals(body.outcome, 'applied')
  assertEquals(records.length, 1)
  assertEquals(records[0].name, 'apply_payment_event')
  assertEquals(records[0].params.p_gateway, 'wompi')
  const payload = records[0].params.p_event as Record<string, unknown>
  assertEquals(payload.transaction_id, 'tx-1')
  assertEquals(payload.amount, 6000)
  assertEquals(payload.status, 'APPROVED')
})

Deno.test('payment-webhook duplicate returns 200 applied=false', async () => {
  const response = await handle(
    post(transactionEvent),
    deps({
      rpcResult: {
        ok: true,
        status: 200,
        body: { applied: false, duplicate: true, outcome: 'ignored' },
      },
    }),
  )
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.applied, false)
  assertEquals(body.outcome, 'ignored')
})

Deno.test('payment-webhook bad checksum -> 401 and no RPC call', async () => {
  const records: Recorded[] = []
  const response = await handle(
    post(transactionEvent),
    { ...deps({ records }), gateway: gateway(approved, false) },
  )
  assertEquals(response.status, 401)
  const body = await response.json()
  assertEquals(body.message, 'InvalidSignatureError')
  assertEquals(records.length, 0)
})

Deno.test('payment-webhook no events secret -> 503 configured=false', async () => {
  const records: Recorded[] = []
  const response = await handle(
    post(transactionEvent),
    deps({ configured: false, records }),
  )
  assertEquals(response.status, 503)
  const body = await response.json()
  assertEquals(body.configured, false)
  assertEquals(records.length, 0)
})

Deno.test('payment-webhook PENDING and non-transaction events -> 200 ignored', async () => {
  const records: Recorded[] = []
  const pending = await handle(
    post(transactionEvent),
    deps({
      event: { ...approved, status: 'PENDING' },
      records,
    }),
  )
  assertEquals(pending.status, 200)
  assertEquals((await pending.json()).ignored, true)

  const other = await handle(
    post({ event: 'transaction.created' }),
    deps({ records }),
  )
  assertEquals(other.status, 200)
  assertEquals((await other.json()).ignored, true)
  assertEquals(records.length, 0)
})

Deno.test('payment-webhook RPC failure -> 500', async () => {
  const response = await handle(
    post(transactionEvent),
    deps({
      rpcResult: { ok: false, status: 500, body: { message: 'UnknownDatabaseError' } },
    }),
  )
  assertEquals(response.status, 500)
})
