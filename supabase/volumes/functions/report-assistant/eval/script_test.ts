import { assertEquals, assertThrows } from 'jsr:@std/assert@^1'
import { replaceScript } from './script.ts'

const fixture = {
  case: 'motorcycle revenue',
  question: 'How much did motorcycles make last month?',
  rpc_outputs: { report_revenue: { total: 1 } },
  model_script: [{ content: [], stop_reason: 'end_turn' }],
  expected: { tools: [], answer: { status: 'answered' } },
}

Deno.test('replaceScript swaps only the model script', () => {
  const turns = [{
    content: [{ type: 'tool_use', id: 'call_1', name: 'get_revenue_report', input: {} }],
    stop_reason: 'tool_use',
  }]
  const next = replaceScript(fixture, turns)
  assertEquals(next.model_script, turns)
  assertEquals(next.question, fixture.question)
  assertEquals(next.rpc_outputs, fixture.rpc_outputs)
  assertEquals(next.expected, fixture.expected)
})

Deno.test('replaceScript never mutates the input fixture', () => {
  const before = structuredClone(fixture)
  replaceScript(fixture, [{ content: [], stop_reason: 'end_turn' }])
  assertEquals(fixture, before)
})

Deno.test('replaceScript refuses an empty recording', () => {
  assertThrows(() => replaceScript(fixture, []), Error, 'empty model script')
})
