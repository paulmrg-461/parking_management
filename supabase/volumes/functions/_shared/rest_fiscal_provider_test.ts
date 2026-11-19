// Tests for the generic REST fiscal provider adapter.

import { assertEquals } from 'jsr:@std/assert@^1'
import { RestFiscalProvider } from './rest_fiscal_provider.ts'

type Captured = { url: string; init: RequestInit }

function provider(
  handler: (url: string, init: RequestInit) => Response | Promise<Response>,
  options: { url?: string; token?: string } = {},
): { adapter: RestFiscalProvider; captured: Captured[] } {
  const captured: Captured[] = []
  const adapter = new RestFiscalProvider({
    url: options.url ?? 'https://provider.test',
    token: options.token ?? 'secret-token',
    environment: 'habilitacion',
    timeoutMs: 1000,
    fetchImpl: ((url: string, init: RequestInit) => {
      captured.push({ url, init })
      return Promise.resolve(handler(url, init))
    }) as typeof fetch,
  })
  return { adapter, captured }
}

const payload = {
  lot_id: 3,
  document: { type: 'pos', full_number: 'SETP7', prefix: 'SETP', number: 7 },
}

Deno.test('rest provider accepted maps cufe and qr', async () => {
  const { adapter, captured } = provider(() =>
    new Response(JSON.stringify({
      id: 'prov-1', status: 'accepted', cufe: 'CUFE-1', qr: 'https://qr/1',
    }), { status: 201 }))

  const result = await adapter.submit(payload, '3-SETP7-pos')

  assertEquals(result.outcome, 'accepted')
  assertEquals(result.cufe, 'CUFE-1')
  assertEquals(result.qrData, 'https://qr/1')
  assertEquals(result.providerDocumentId, 'prov-1')
  const init = captured[0].init
  const headers = init.headers as Record<string, string>
  assertEquals(headers['Idempotency-Key'], '3-SETP7-pos')
  assertEquals(headers.Authorization, 'Bearer secret-token')
  const body = JSON.parse(String(init.body))
  assertEquals(body.document.environment, 'habilitacion')
})

Deno.test('rest provider processing maps to pending', async () => {
  const { adapter } = provider(() =>
    new Response(JSON.stringify({ id: 'prov-2', status: 'processing' }), { status: 200 }))

  const result = await adapter.submit(payload, 'key')
  assertEquals(result.outcome, 'pending')
  assertEquals(result.providerDocumentId, 'prov-2')
})

Deno.test('rest provider 422 maps to rejected with the messages', async () => {
  const { adapter } = provider(() =>
    new Response(JSON.stringify({
      status: 'rejected',
      errors: [{ code: 'F01', message: 'NIT inválido' }, { message: 'Rango vencido' }],
    }), { status: 422 }))

  const result = await adapter.submit(payload, 'key')
  assertEquals(result.outcome, 'rejected')
  assertEquals(result.rejectionReason, 'NIT inválido; Rango vencido')
})

for (const status of [408, 429, 500, 503]) {
  Deno.test(`rest provider ${status} maps to transient_error`, async () => {
    const { adapter } = provider(() => new Response('down', { status }))
    const result = await adapter.submit(payload, 'key')
    assertEquals(result.outcome, 'transient_error')
    assertEquals(result.error?.includes('secret-token'), false)
  })
}

Deno.test('rest provider network error maps to transient_error', async () => {
  const { adapter } = provider(() => Promise.reject(new Error('offline')))
  const result = await adapter.submit(payload, 'key')
  assertEquals(result.outcome, 'transient_error')
  assertEquals(result.error, 'provider network error')
})

Deno.test('rest provider query polls the document id', async () => {
  const { adapter, captured } = provider(() =>
    new Response(JSON.stringify({ id: 'prov-9', status: 'accepted', cufe: 'C' }), { status: 200 }))

  const result = await adapter.query('prov-9')
  assertEquals(result.outcome, 'accepted')
  assertEquals(captured[0].url, 'https://provider.test/v1/documents/prov-9')
  assertEquals(captured[0].init.method, 'GET')
})

Deno.test('rest provider without credentials is not configured', () => {
  const { adapter } = provider(() => new Response('{}'), { url: '', token: '' })
  assertEquals(adapter.isConfigured(), false)
})

Deno.test('rest provider never echoes the token in a rejection', async () => {
  const { adapter } = provider(() =>
    new Response(JSON.stringify({ status: 'rejected', errors: [{ message: 'bad' }] }), { status: 400 }))
  const result = await adapter.submit(payload, 'key')
  assertEquals(JSON.stringify(result).includes('secret-token'), false)
})
