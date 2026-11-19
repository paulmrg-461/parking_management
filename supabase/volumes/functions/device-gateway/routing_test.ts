import { assertEquals } from 'jsr:@std/assert@^1'
import { matchRoute } from './routing.ts'

const fn = (path: string) => `/functions/v1/device-gateway${path}`

Deno.test('matches the fixed routes behind the function prefix', () => {
  assertEquals(matchRoute('GET', fn('/v1/time'))?.name, 'time')
  assertEquals(matchRoute('POST', fn('/v1/heartbeat'))?.name, 'heartbeat')
  assertEquals(matchRoute('GET', fn('/v1/lpr/config'))?.name, 'lpr_config')
  assertEquals(matchRoute('POST', fn('/v1/lpr/reads'))?.name, 'lpr_reads')
})

Deno.test('matches named segments and rejects extra segments', () => {
  const matched = matchRoute('PUT', fn('/v1/lpr/events/42/snapshot'))
  assertEquals(matched?.name, 'lpr_snapshot')
  assertEquals(matched?.params['id'], '42')
  assertEquals(
    matchRoute('PUT', fn('/v1/lpr/events/42/snapshot/extra')),
    null,
  )
  assertEquals(matchRoute('PUT', fn('/v1/lpr/events/snapshot')), null)
})

Deno.test('a route only matches its method', () => {
  assertEquals(matchRoute('GET', fn('/v1/heartbeat')), null)
  assertEquals(matchRoute('POST', fn('/v1/time')), null)
  assertEquals(matchRoute('GET', fn('/v1/unknown')), null)
})
