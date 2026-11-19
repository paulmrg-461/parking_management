import { assertEquals, assertThrows } from 'jsr:@std/assert@^1'
import { isConfigured, loadConfig } from './config.ts'
import { callerFrom } from './caller.ts'
import { Deadline } from './deadline.ts'
import { fromPostgrest } from './errors.ts'
import { logLine } from './log.ts'
import { encodeEvent } from './sse.ts'

Deno.test('ai config defaults', () => {
  const cfg = loadConfig({})
  assertEquals(cfg.model, 'deepseek-chat')
  assertEquals(cfg.maxIterations, 6)
  assertEquals(cfg.maxTokensPerRequest, 60000)
  assertEquals(isConfigured(cfg), false)
})

Deno.test('ai config reads the key and rejects bad limits', () => {
  const cfg = loadConfig({ DEEPSEEK_API_KEY: ' key ', AI_REPORT_MAX_ITERATIONS: 'x' })
  assertEquals(cfg.apiKey, 'key')
  assertEquals(isConfigured(cfg), true)
  assertEquals(cfg.maxIterations, 6)
})

Deno.test('fromPostgrest maps typed names and hides internals', () => {
  assertEquals(fromPostgrest(401, { message: 'InvalidTokenError' }).status, 401)
  assertEquals(fromPostgrest(403, { message: 'AdminRequiredError' }).status, 403)
  assertEquals(fromPostgrest(400, { message: 'LotRequiredError' }).status, 400)
  assertEquals(fromPostgrest(429, { message: 'AiBudgetExceededError' }).status, 429)
  const unknown = fromPostgrest(500, { message: 'secret stack trace' })
  assertEquals(unknown.code, 'AiUpstreamError')
  assertEquals(JSON.stringify(unknown).includes('secret'), false)
})

Deno.test('caller requires authorization and lot', () => {
  assertThrows(
    () => callerFrom(new Request('https://x', { method: 'POST' }), 'anon'),
    Error,
    'InvalidTokenError',
  )
  assertThrows(
    () => callerFrom(
      new Request('https://x', {
        method: 'POST',
        headers: { Authorization: 'Bearer t' },
      }),
      'anon',
    ),
    Error,
    'LotRequiredError',
  )
})

Deno.test('deadline expires', async () => {
  const deadline = new Deadline(1)
  await new Promise((resolve) => setTimeout(resolve, 5))
  assertEquals(deadline.remaining(), 0)
})

Deno.test('log line drops content fields', () => {
  const lines: string[] = []
  const original = console.log
  console.log = (value: string) => lines.push(value)
  try {
    logLine({ fn: 'x', question: 'secret', answer: 'secret', result: 1, status: 'ok' })
  } finally {
    console.log = original
  }
  assertEquals(lines.length, 1)
  assertEquals(lines[0].includes('secret'), false)
  assertEquals(lines[0].includes('question'), false)
  assertEquals(lines[0].includes('"status":"ok"'), true)
})

Deno.test('sse encodes events', () => {
  assertEquals(encodeEvent('started', { id: 1 }), 'event: started\ndata: {"id":1}\n\n')
})
