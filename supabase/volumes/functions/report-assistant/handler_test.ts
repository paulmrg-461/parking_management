import { assertEquals } from 'jsr:@std/assert@^1'
import { loadConfig } from '../_shared/ai/config.ts'
import type {
  ContentBlock,
  ModelClient,
  ModelResult,
} from '../_shared/ai/types.ts'
import { createHandler, type HandlerDeps } from './handler.ts'

function message(content: ContentBlock[]): ModelResult {
  return {
    content,
    stop_reason: content.some((block) => block.type === 'tool_use')
      ? 'tool_use'
      : 'end_turn',
    usage: { input: 100, output: 20, cacheRead: 0, cacheWrite: 0, total: 120 },
    model: 'deepseek-chat',
  }
}

class ScriptedModel implements ModelClient {
  readonly name = 'scripted'
  calls = 0
  constructor(
    private readonly script: ModelResult[],
  ) {}
  create(): Promise<ModelResult> {
    const next = this.script[this.calls]
    this.calls += 1
    if (!next) throw new Error('script exhausted')
    return Promise.resolve(next)
  }
}

function deps(options: {
  key?: string
  script?: ModelResult[]
  rpc?: () => { ok: true; body: unknown } | { ok: false; error: Error }
  calls?: Array<{ name: string; args: Record<string, unknown> }>
} = {}): HandlerDeps {
  const calls = options.calls ?? []
  return {
    cfg: { ...loadConfig({}), apiKey: options.key ?? 'key' },
    model: new ScriptedModel(options.script ?? []),
    anonKey: 'anon',
    rpcGet: (_caller, name, args) => {
      calls.push({ name, args })
      const result = options.rpc?.()
      if (result && !result.ok) throw result.error
      return Promise.resolve(result ?? { ok: true, body: { total: 11900 } })
    },
    restGet: () => Promise.resolve([{
      business_timezone: 'America/Bogota',
      currency: 'COP',
    }]),
    reserve: () => Promise.resolve({ requestId: 7 }),
    record: () => Promise.resolve(),
    status: () => Promise.resolve({ daily_requests: 100, used_requests: 0 }),
    now: () => new Date('2026-11-10T12:00:00Z'),
  }
}

const post = (body: unknown, headers: Record<string, string> = {}) =>
  new Request('https://fn.test/report-assistant', {
    method: 'POST',
    headers: {
      Authorization: 'Bearer token',
      'x-lot-id': '1',
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
      ...headers,
    },
    body: JSON.stringify(body),
  })

const ask = { mode: 'ask', question: 'How much did motorcycles make?', locale: 'en' }

const happyScript = [
  message([{
    type: 'tool_use',
    id: 'call1',
    name: 'get_revenue_report',
    input: { start_date: '2026-10-01', end_date: '2026-10-31' },
  }]),
  message([{
    type: 'tool_use',
    id: 'submit',
    name: 'submit_answer',
    input: {
      status: 'answered',
      headline: 'Revenue was {f1}.',
      explanation: 'From the revenue report.',
      period_start: '2026-10-01',
      period_end: '2026-10-31',
      figures: [{
        id: 'f1',
        label: 'Revenue',
        unit: 'money',
        op: 'value',
        operands: [{ call_id: 'call1', path: 'total' }],
      }],
      caveats: [],
    },
  }]),
]

Deno.test('handler options and method guard', async () => {
  const handler = createHandler(deps())
  const options = await handler(new Request('https://fn.test', { method: 'OPTIONS' }))
  assertEquals(options.status, 204)
  const get = await handler(new Request('https://fn.test', { method: 'GET' }))
  assertEquals(get.status, 405)
})

Deno.test('handler missing authorization is 401', async () => {
  const handler = createHandler(deps())
  const response = await handler(new Request('https://fn.test', {
    method: 'POST',
    body: JSON.stringify({ mode: 'status' }),
  }))
  assertEquals(response.status, 401)
  assertEquals((await response.json()).message, 'InvalidTokenError')
})

Deno.test('handler without key is inert and never reserves', async () => {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = []
  const handler = createHandler(deps({ key: '', calls }))
  const status = await handler(post({ mode: 'status' }))
  assertEquals((await status.json()).configured, false)

  const response = await handler(post(ask))
  assertEquals(response.status, 503)
  assertEquals((await response.json()).message, 'AiUnavailableError')
  assertEquals(calls.length, 0)
})

Deno.test('handler status returns the budget', async () => {
  const handler = createHandler(deps())
  const response = await handler(post({ mode: 'status' }))
  const body = await response.json()
  assertEquals(body.configured, true)
  assertEquals(body.budget.daily_requests, 100)
})

Deno.test('handler ask streams started tool answer done', async () => {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = []
  const handler = createHandler(deps({ script: happyScript, calls }))
  const response = await handler(post(ask))
  assertEquals(response.status, 200)
  assertEquals(response.headers.get('Content-Type'), 'text/event-stream')
  const text = await response.text()

  assertEquals(text.includes('event: started'), true)
  assertEquals(text.includes('event: tool'), true)
  assertEquals(text.includes('event: answer'), true)
  assertEquals(text.includes('event: done'), true)
  assertEquals(text.includes('"value":11900'), true)
  assertEquals(calls[0].name, 'report_revenue')
})

Deno.test('handler JSON fallback returns the answer', async () => {
  const handler = createHandler(deps({ script: happyScript }))
  const response = await handler(post(ask, { Accept: 'application/json' }))
  const body = await response.json()
  assertEquals(response.status, 200)
  assertEquals(body.answer.figures[0].value, 11900)
})

Deno.test('handler redacts a plate and flags it', async () => {
  const script = [
    message([{
      type: 'tool_use', id: 'submit', name: 'submit_answer',
      input: {
        status: 'out_of_scope',
        headline: 'Use vehicle history.',
        explanation: '', period_start: '', period_end: '',
        figures: [], caveats: [],
      },
    }]),
  ]
  const handler = createHandler(deps({ script }))
  const response = await handler(post(
    { ...ask, question: 'How much did ABC123 pay?' },
    { Accept: 'application/json' },
  ))
  const body = await response.json()
  assertEquals(body.answer.question_redacted, true)
})

Deno.test('handler rejects a bad body', async () => {
  const handler = createHandler(deps())
  const response = await handler(post({ mode: 'ask', question: '', locale: 'es' }))
  assertEquals(response.status, 400)
  assertEquals((await response.json()).message, 'AiQuestionInvalidError')
})
