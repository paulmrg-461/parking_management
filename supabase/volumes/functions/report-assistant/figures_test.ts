import { assertEquals, assertThrows } from 'jsr:@std/assert@^1'
import { computeOp } from './figures/ops.ts'
import { resolvePath } from './figures/path.ts'

const units = { amount: 'money', total: 'money', hour: 'hour', entries: 'count' } as const
const data = {
  total: 11900,
  hours: [
    { hour: 7, entries: 10 },
    { hour: 8, entries: 30 },
  ],
  by_category: [
    { category_name: 'Moto', amount: 4820000 },
    { category_name: 'Car', amount: 100 },
  ],
}

Deno.test('resolve selector by field', () => {
  const result = resolvePath(data, 'by_category[category_name=Moto].amount', units)
  assertEquals(result.values, [4820000])
  assertEquals(result.leaf, 'amount')
})

Deno.test('resolve index and star', () => {
  assertEquals(resolvePath(data, 'hours[0].entries', units).values, [10])
  assertEquals(resolvePath(data, 'hours[*].entries', units).values, [10, 30])
})

Deno.test('reject unknown leaf, non-integer, prototype keys, long paths', () => {
  assertThrows(() => resolvePath(data, 'total_other' as string, units))
  assertThrows(() => resolvePath({ total: 1.5 }, 'total', units))
  assertThrows(() => resolvePath({ __proto__: { total: 1 } }, '__proto__.total', units))
  assertThrows(() => resolvePath(data, 'a'.repeat(130), units))
})

Deno.test('ops round half away from zero', () => {
  assertEquals(computeOp('percent_change', [3, 4], 'count').value, 3333)
  assertEquals(computeOp('percent_change', [-3, -4], 'count').value, 3333)
  assertEquals(computeOp('share_percent', [4820000, 11900], 'money').value, 4050420)
  assertEquals(computeOp('difference', [5, 8], 'count').value, -3)
  assertEquals(computeOp('sum', [1, 2, 3], 'count').value, 6)
  const zero = computeOp('percent_change', [0, 4], 'count')
  assertEquals(zero.value, null)
  assertEquals(zero.note, 'undefined_base')
})
