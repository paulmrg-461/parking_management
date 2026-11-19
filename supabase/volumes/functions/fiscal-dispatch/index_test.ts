// Tests for the fiscal-dispatch Edge Function.

import { assertEquals } from 'jsr:@std/assert@^1'
import type { FiscalProvider, FiscalResult } from '../_shared/fiscal_provider.ts'
import { handle, type FiscalDispatchDeps } from './index.ts'

type Recorded = { name: string; params: Record<string, unknown> }

const pendingDoc = {
  id: 7,
  status: 'pending',
  provider_document_id: null,
  payload: {
    lot_id: 3,
    document: { type: 'pos', full_number: 'SETP7', prefix: 'SETP', number: 7 },
  },
}

const sentDoc = {
  id: 8,
  status: 'sent',
  provider_document_id: 'prov-8',
  payload: {
    lot_id: 3,
    document: { type: 'invoice', full_number: 'FE8', prefix: 'FE', number: 8 },
  },
}

function provider(options: {
  configured?: boolean
  result?: FiscalResult
  submitted?: Array<{ payload: unknown; key: string }>
  queried?: string[]
} = {}): FiscalProvider {
  return {
    name: 'fake',
    isConfigured: () => options.configured ?? true,
    submit: (payload, key) => {
      options.submitted?.push({ payload, key })
      return Promise.resolve(options.result ?? { outcome: 'accepted', cufe: 'C' })
    },
    query: (id) => {
      options.queried?.push(id)
      return Promise.resolve(options.result ?? { outcome: 'accepted', cufe: 'C' })
    },
  }
}

function deps(options: {
  provider?: FiscalProvider
  documents?: unknown[]
  claimFails?: boolean
  records?: Recorded[]
  recordFails?: boolean
} = {}): FiscalDispatchDeps {
  const records = options.records ?? []
  return {
    provider: options.provider ?? provider(),
    serviceKey: () => 'service-key',
    rpc: (name, params) => {
      records.push({ name, params })
      if (name === 'claim_fiscal_documents') {
        return Promise.resolve(
          options.claimFails
            ? { ok: false, status: 500, body: { message: 'ServerError' } }
            : { ok: true, status: 200, body: options.documents ?? [pendingDoc] },
        )
      }
      return Promise.resolve(
        options.recordFails
          ? { ok: false, status: 500, body: { message: 'ServerError' } }
          : { ok: true, status: 200, body: { status: 'accepted' } },
      )
    },
  }
}

const post = (key = 'service-key') =>
  new Request('https://fn.test/fiscal-dispatch', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}` },
  })

Deno.test('fiscal-dispatch rejects a non service key', async () => {
  const records: Recorded[] = []
  const response = await handle(post('anon'), deps({ records }))
  assertEquals(response.status, 403)
  assertEquals(records.length, 0)
})

Deno.test('fiscal-dispatch without credentials is inert', async () => {
  const records: Recorded[] = []
  const response = await handle(
    post(),
    deps({ records, provider: provider({ configured: false }) }),
  )
  assertEquals(response.status, 200)
  assertEquals((await response.json()).configured, false)
  assertEquals(records.length, 0)
})

Deno.test('fiscal-dispatch queue read failure is a 500', async () => {
  const response = await handle(post(), deps({ claimFails: true }))
  assertEquals(response.status, 500)
})

Deno.test('fiscal-dispatch submits a pending document and records it', async () => {
  const submitted: Array<{ payload: unknown; key: string }> = []
  const records: Recorded[] = []
  const response = await handle(
    post(),
    deps({ records, provider: provider({ submitted }) }),
  )
  const body = await response.json()

  assertEquals(body.claimed, 1)
  assertEquals(body.accepted, 1)
  assertEquals(submitted.length, 1)
  assertEquals(submitted[0].key, '3-SETP7-pos')
  assertEquals(records[1].name, 'record_fiscal_result')
  assertEquals((records[1].params.p_result as FiscalResult).outcome, 'accepted')
})

Deno.test('fiscal-dispatch queries a sent document', async () => {
  const queried: string[] = []
  const response = await handle(
    post(),
    deps({
      documents: [sentDoc],
      provider: provider({ queried }),
    }),
  )
  assertEquals(queried, ['prov-8'])
  assertEquals((await response.json()).claimed, 1)
})

Deno.test('fiscal-dispatch counts rejected and retried outcomes', async () => {
  const response = await handle(
    post(),
    deps({
      documents: [pendingDoc, sentDoc],
      provider: provider({ result: { outcome: 'rejected', rejectionReason: 'x' } }),
    }),
  )
  const body = await response.json()
  assertEquals(body.rejected, 2)
  assertEquals(body.accepted, 0)
})

Deno.test('fiscal-dispatch counts a record failure without throwing', async () => {
  const response = await handle(post(), deps({ recordFails: true }))
  const body = await response.json()
  assertEquals(body.failed, 1)
  assertEquals(response.status, 200)
})

Deno.test('fiscal-dispatch token never appears in the answer', async () => {
  const response = await handle(
    post(),
    deps({
      provider: provider({
        result: { outcome: 'transient_error', error: 'provider network error' },
      }),
    }),
  )
  const text = await response.text()
  assertEquals(text.includes('service-key'), false)
})
