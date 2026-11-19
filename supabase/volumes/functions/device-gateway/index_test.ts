import { assertEquals } from 'jsr:@std/assert@^1'
import { createHandler, type GatewayDeps } from './index.ts'

async function goodHash(): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode('pkd_3fa94c0b12de_' + 'a'.repeat(64)),
  )
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

function deps(options: {
  accept?: Record<string, unknown>
  hash?: string
} = {}): GatewayDeps {
  return {
    serviceKey: () => 'service',
    lookup: () => Promise.resolve({
      id: 7,
      key_hash: options.hash ?? '',
    }),
    accept: () => Promise.resolve(options.accept ?? {
      ok: true, device_id: 7, lot_id: 1, kind: 'barrier', name: 'B1',
    }),
    heartbeat: () => Promise.resolve({
      server_time: '2026-11-18T12:00:00Z',
      heartbeat_interval_s: 60,
      offline_minutes: 5,
    }),
    authFailure: () => Promise.resolve(),
    now: () => new Date('2026-11-18T12:00:00Z'),
    lpr: {
      config: () => Promise.resolve({
        direction: 'entry',
        min_confidence: 0.8,
        vote_window_seconds: 8,
        heartbeat_interval_s: 60,
      }),
      read: () => Promise.resolve({
        read_id: 1,
        outcome: 'recorded',
        event: null,
        snapshot_wanted: false,
      }),
      attach: () => Promise.resolve({ event_id: 1, session_id: null }),
      upload: () => Promise.resolve({ status: 200 }),
      remove: () => Promise.resolve(),
    },
    barrier: {
      config: () => Promise.resolve({
        direction: 'entry',
        open_hold_ms: 1000,
        max_open_seconds: 20,
        post_clear_delay_ms: 1500,
        max_reversals: 3,
        command_ttl_seconds: 30,
      }),
      next: () => Promise.resolve(null),
      ack: () => Promise.resolve({ status: 'executed' }),
      event: () => Promise.resolve({ ok: true }),
      firmware: () => Promise.resolve(null),
      image: () => Promise.resolve(null),
      signer: () =>
        Promise.resolve({ publicKey: '', sign: () => Promise.resolve('sig') }),
      sleep: () => Promise.resolve(),
    },
  }
}

const post = (key: string, seq = '1', timestamp = '1763467200') =>
  new Request('https://fn.test/device-gateway/v1/heartbeat', {
    method: 'POST',
    headers: {
      'X-Device-Key': key,
      'X-Device-Seq': seq,
      'X-Device-Timestamp': timestamp,
    },
    body: JSON.stringify({ status: { uptime_s: 10 } }),
  })

Deno.test('gateway time is public', async () => {
  const response = await createHandler(deps())(new Request(
    'https://fn.test/device-gateway/v1/time',
  ))
  assertEquals(response.status, 200)
  assertEquals((await response.json()).max_skew_s, 300)
})

Deno.test('gateway refuses a missing or malformed key', async () => {
  const handler = createHandler(deps())
  assertEquals((await handler(post(''))).status, 401)
  assertEquals((await handler(post('pkd_bad'))).status, 401)
})

Deno.test('gateway refuses a wrong key', async () => {
  let failed = false
  const handler = createHandler({
    ...deps({ hash: 'f'.repeat(64) }),
    authFailure: () => {
      failed = true
      return Promise.resolve()
    },
  })
  const key = 'pkd_3fa94c0b12de_' + 'a'.repeat(64)
  assertEquals((await handler(post(key))).status, 401)
  assertEquals(failed, true)
})

Deno.test('gateway accepts a valid heartbeat', async () => {
  const handler = createHandler(deps({ hash: await goodHash() }))
  const key = 'pkd_3fa94c0b12de_' + 'a'.repeat(64)
  const response = await handler(post(key))
  const body = await response.json()
  assertEquals(response.status, 200)
  assertEquals(body.device.kind, 'barrier')
  assertEquals(body.offline_minutes, 5)
})

Deno.test('gateway maps replay, skew, disabled and rate errors', async () => {
  const key = 'pkd_3fa94c0b12de_' + 'a'.repeat(64)
  for (const [error, status] of [
    ['DeviceReplayError', 409],
    ['DeviceClockSkewError', 400],
    ['DeviceDisabledError', 401],
    ['DeviceRateLimitedError', 429],
  ] as const) {
    const handler = createHandler(deps({
      hash: await goodHash(),
      accept: { ok: false, error },
    }))
    assertEquals((await handler(post(key))).status, status, error)
  }
})
