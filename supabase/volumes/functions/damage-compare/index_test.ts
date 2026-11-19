import { assertEquals } from 'jsr:@std/assert@^1'
import { AiError } from '../_shared/ai/errors.ts'
import { loadConfig } from '../_shared/ai/config.ts'
import { createHandler, normalise, type DamageDeps } from './index.ts'

function deps(options: {
  key?: string
  begin?: () => Promise<unknown>
  vision?: () => Promise<unknown>
  stored?: boolean
} = {}): DamageDeps {
  return {
    cfg: { ...loadConfig({}), apiKey: options.key ?? 'key' },
    anonKey: 'anon',
    reserve: () => Promise.resolve({ requestId: 5 }),
    begin: (options.begin as never) ?? (() => Promise.resolve({
      comparisonId: 9,
      entryPhotos: [{ id: 1, path: 'entry/1.jpg' }],
      exitPhotos: [{ id: 2, path: 'exit/2.jpg' }],
    })),
    images: (_ctx, photos, label) => Promise.resolve(
      photos.map((photo, index) => ({
        label: `${label}${index + 1}`,
        dataUrl: `data:image/jpeg;base64,${photo.id}`,
      })),
    ),
    vision: (options.vision as never) ?? (() => Promise.resolve({
      content: JSON.stringify({
        overall: 'possible_new_damage',
        summary: 'Posible rayón.',
        quality: { same_vehicle: 'yes', covered_zones: ['left'], issues: [] },
        findings: [{
          zone: 'left',
          description: 'Rayón',
          classification: 'new',
          confidence: 'high',
          entry_photo_ids: [1],
          exit_photo_ids: [2],
        }],
      }),
      model: 'deepseek-flash',
      usage: { input: 100, output: 20 },
    })),
    store: () => Promise.resolve(options.stored ?? true),
    fail: () => Promise.resolve(),
    record: () => Promise.resolve(),
    status: () => Promise.resolve({ remaining_requests: 59 }),
    now: () => new Date('2026-11-18T12:00:00Z'),
  }
}

const post = (body: unknown, key = 'Bearer token') =>
  new Request('https://fn.test/damage-compare', {
    method: 'POST',
    headers: {
      Authorization: key,
      'x-lot-id': '1',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })

Deno.test('damage status without key is inert', async () => {
  const response = await createHandler(deps({ key: '' }))(post({ mode: 'status' }))
  assertEquals(response.status, 200)
  assertEquals((await response.json()).configured, false)
})

Deno.test('damage ask without key is 503 and reserves nothing', async () => {
  let called = false
  const handler = createHandler({
    ...deps({ key: '' }),
    reserve: () => {
      called = true
      return Promise.resolve({ requestId: 1 })
    },
  })
  const response = await handler(post({ mode: 'run', session_id: 1, locale: 'es' }))
  assertEquals(response.status, 503)
  assertEquals((await response.json()).message, 'AiUnavailableError')
  assertEquals(called, false)
})

Deno.test('damage bad body is 400', async () => {
  const response = await createHandler(deps())(
    post({ mode: 'run', session_id: -1, locale: 'es' }),
  )
  assertEquals(response.status, 400)
})

Deno.test('damage run normalises and stores the comparison', async () => {
  const handler = createHandler(deps())
  const response = await handler(post({ mode: 'run', session_id: 1, locale: 'es' }))
  const body = await response.json()
  assertEquals(response.status, 200)
  assertEquals(body.comparison_id, 9)
  assertEquals(body.overall, 'possible_new_damage')
  assertEquals(body.findings[0].classification, 'new')
})

Deno.test('damage insufficient evidence is 422 and marks failed', async () => {
  let failed = false
  const handler = createHandler({
    ...deps({
      begin: () => Promise.reject(new AiError('InsufficientEvidenceError', 422)),
    }),
    fail: () => {
      failed = true
      return Promise.resolve()
    },
  })
  const response = await handler(post({ mode: 'run', session_id: 1, locale: 'es' }))
  assertEquals(response.status, 422)
})

Deno.test('damage downgrades a new finding without exit photos', async () => {
  const handler = createHandler(deps({
    vision: () => Promise.resolve({
      content: JSON.stringify({
        overall: 'possible_new_damage',
        summary: 'x',
        quality: { same_vehicle: 'yes' },
        findings: [{
          zone: 'left', description: 'x', classification: 'new',
          confidence: 'high', entry_photo_ids: [1], exit_photo_ids: [],
        }],
      }),
      model: 'm',
      usage: {},
    }),
  }))
  const body = await (await handler(
    post({ mode: 'run', session_id: 1, locale: 'es' }),
  )).json()
  assertEquals(body.findings[0].classification, 'uncertain')
  assertEquals(body.overall, 'insufficient_evidence')
})

Deno.test('damage coverage floor is configurable', () => {
  const answer = {
    quality: { same_vehicle: 'yes', covered_zones: ['front', 'rear'] },
    findings: [],
  }
  assertEquals(normalise(answer, [1], [2], 2).overall, 'no_new_damage')
  assertEquals(normalise(answer, [1], [2], 3).overall, 'insufficient_evidence')
  // A zero falls back to one zone: the check is never disabled entirely.
  assertEquals(normalise(answer, [1], [2], 0).overall, 'no_new_damage')
})

Deno.test('damage run honours the configured coverage floor', async () => {
  const vision = () => Promise.resolve({
    content: JSON.stringify({
      summary: 'Sin cambios.',
      quality: { same_vehicle: 'yes', covered_zones: ['front', 'rear'], issues: [] },
      findings: [],
    }),
    model: 'm',
    usage: {},
  })
  const twoZones = await (await createHandler({ ...deps({ vision }), minCoveredZones: 2 })(
    post({ mode: 'run', session_id: 1, locale: 'es' }),
  )).json()
  assertEquals(twoZones.overall, 'no_new_damage')
  const strict = await (await createHandler(deps({ vision }))(
    post({ mode: 'run', session_id: 1, locale: 'es' }),
  )).json()
  assertEquals(strict.overall, 'insufficient_evidence')
})
