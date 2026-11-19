import { assertEquals } from 'jsr:@std/assert@^1'
import { validateAnswer, type IssuedResult } from './answer.ts'
import { revenueTool } from './testing/tools.ts'

function issued(): Map<string, IssuedResult> {
  return new Map([['call1', {
    callId: 'call1',
    rpc: 'report_revenue',
    args: { p_start_date: '2026-10-01', p_end_date: '2026-10-31' },
    projected: { total: 11900, by_category: [{ category_name: 'Moto', amount: 4820000 }] },
    tool: revenueTool,
  }]])
}

function answer(overrides: Record<string, unknown> = {}) {
  return {
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
    ...overrides,
  }
}

Deno.test('valid answer resolves figures from issued results', () => {
  const check = validateAnswer(answer(), issued())
  assertEquals(check.ok, true)
  if (check.ok) {
    assertEquals(check.answer.figures[0].value, 11900)
    assertEquals(check.answer.figures[0].sources[0].rpc, 'report_revenue')
  }
})

Deno.test('reject digits in prose except years', () => {
  const bad = validateAnswer(answer({ headline: 'Revenue was 99 in 2026.' }), issued())
  assertEquals(bad.ok, false)
})

Deno.test('reject unknown call, unit mismatch and placeholders without figures', () => {
  const unknown = validateAnswer(answer({
    figures: [{
      id: 'f1', label: 'x', unit: 'money', op: 'value',
      operands: [{ call_id: 'other', path: 'total' }],
    }],
  }), issued())
  assertEquals(unknown.ok, false)

  const mismatch = validateAnswer(answer({
    figures: [{
      id: 'f1', label: 'x', unit: 'count', op: 'value',
      operands: [{ call_id: 'call1', path: 'total' }],
    }],
  }), issued())
  assertEquals(mismatch.ok, false)

  const placeholder = validateAnswer(answer({
    headline: 'Revenue was {f2}.',
  }), issued())
  assertEquals(placeholder.ok, false)
})

Deno.test('non-answered status requires no figures', () => {
  const check = validateAnswer(answer({
    status: 'out_of_scope',
    headline: 'Use vehicle history.',
    explanation: '',
  }), issued())
  assertEquals(check.ok, false)
  const clean = validateAnswer(answer({
    status: 'out_of_scope',
    headline: 'Use vehicle history.',
    explanation: '',
    figures: [],
  }), issued())
  assertEquals(clean.ok, true)
})
