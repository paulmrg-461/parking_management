import { assertEquals } from 'jsr:@std/assert@^1'
import { evalRefusal } from './eval_guard.ts'

Deno.test('live eval refuses in CI even with a key', () => {
  assertEquals(
    evalRefusal({ CI: 'true', DEEPSEEK_API_KEY: 'k' }),
    'eval:live is manual only and refuses to run in CI',
  )
  assertEquals(
    evalRefusal({ CI: 'TRUE', DEEPSEEK_API_KEY: 'k' }),
    'eval:live is manual only and refuses to run in CI',
  )
})

Deno.test('live eval refuses without a key', () => {
  assertEquals(
    evalRefusal({}),
    'eval:live needs DEEPSEEK_API_KEY (it spends tokens)',
  )
  assertEquals(
    evalRefusal({ DEEPSEEK_API_KEY: '   ' }),
    'eval:live needs DEEPSEEK_API_KEY (it spends tokens)',
  )
})

Deno.test('live eval runs with a key outside CI', () => {
  assertEquals(evalRefusal({ DEEPSEEK_API_KEY: 'k', CI: 'false' }), null)
})
