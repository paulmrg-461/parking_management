import { assertEquals } from 'jsr:@std/assert@^1'
import { createHandler, type GatewayDeps } from './index.ts'

const KEY = 'pkd_3fa94c0b12de_' + 'a'.repeat(64)
const CHANNELS = [
  { ch: 1, state: 'occupied', raw: 900, at: '2026-11-20T10:00:00Z' },
  { ch: 2, state: 'free', raw: 2200, at: '2026-11-20T10:00:00Z' },
]

async function hash(): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(KEY),
  )
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

function deps(options: {
  kind?: string
  config?: () => Promise<Record<string, unknown>>
  report?: (
    deviceId: number,
    channels: unknown,
    full: boolean,
  ) => Promise<Record<string, unknown>>
  firmware?: () => Promise<Record<string, unknown> | null>
  image?: () => Promise<Uint8Array | null>
} = {}): GatewayDeps {
  return {
    serviceKey: () => 'service',
    lookup: () => Promise.resolve({ id: 7, key_hash: '' }),
    accept: () => Promise.resolve({
      ok: true,
      device_id: 7,
      lot_id: 1,
      kind: options.kind ?? 'sensor_hub',
      name: 'Hub',
    }),
    heartbeat: () => Promise.resolve({}),
    authFailure: () => Promise.resolve(),
    now: () => new Date('2026-11-20T12:00:00Z'),
    lpr: {
      config: () => Promise.resolve({}),
      read: () => Promise.resolve({}),
      attach: () => Promise.resolve({}),
      upload: () => Promise.resolve({ status: 200 }),
      remove: () => Promise.resolve(),
    },
    barrier: {
      config: () => Promise.resolve({}),
      next: () => Promise.resolve(null),
      ack: () => Promise.resolve({ status: 'executed' }),
      event: () => Promise.resolve({ ok: true }),
      firmware: () => Promise.resolve(null),
      image: () => Promise.resolve(null),
      signer: () =>
        Promise.resolve({ publicKey: '', sign: () => Promise.resolve('sig') }),
      sleep: () => Promise.resolve(),
    },
    bays: {
      config: options.config ?? (() => Promise.resolve({
        report_interval_s: 60,
        stable_ms: 5000,
        channels: [{ ch: 1, type: 'ultrasonic', mapped: true }],
      })),
      report: options.report ?? (() => Promise.resolve({
        accepted: 2,
        ignored: 0,
        created_channels: [1, 2],
      })),
      firmware: options.firmware ?? (() => Promise.resolve(null)),
      image: options.image ?? (() => Promise.resolve(null)),
    },
  }
}

async function authorised(options: Parameters<typeof deps>[0] = {}) {
  const keyHash = await hash()
  return {
    ...deps(options),
    lookup: () => Promise.resolve({ id: 7, key_hash: keyHash }),
  }
}

const headers = () => ({
  'X-Device-Key': KEY,
  'X-Device-Seq': '1',
  'X-Device-Timestamp': '1763467200',
})

const request = (path: string, init: RequestInit = {}) =>
  new Request(`https://fn.test/functions/v1/device-gateway${path}`, {
    ...init,
    headers: { ...headers(), ...(init.headers ?? {}) },
  })

Deno.test('bays config returns the channels', async () => {
  const handler = createHandler(await authorised())
  const response = await handler(request('/v1/bays/config'))
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.stable_ms, 5000)
  assertEquals(body.channels[0].ch, 1)
})

Deno.test('bays report forwards channels and full and returns counts', async () => {
  let received: Record<string, unknown> = {}
  const handler = createHandler(await authorised({
    report: (deviceId, channels, full) => {
      received = { deviceId, channels, full }
      return Promise.resolve({ accepted: 2, ignored: 0, created_channels: [] })
    },
  }))
  const response = await handler(request('/v1/bays/report', {
    method: 'POST',
    body: JSON.stringify({ channels: CHANNELS, full: true, lot_id: 999 }),
  }))
  assertEquals(response.status, 200)
  assertEquals((await response.json()).accepted, 2)
  assertEquals(received['deviceId'], 7)
  assertEquals((received['channels'] as unknown[]).length, 2)
  assertEquals(received['full'], true)
})

Deno.test('bays report rejects a body over 16 KiB and malformed JSON', async () => {
  const handler = createHandler(await authorised())
  const big = await handler(request('/v1/bays/report', {
    method: 'POST',
    body: JSON.stringify({ channels: CHANNELS, pad: 'x'.repeat(17000) }),
  }))
  assertEquals(big.status, 413)
  const malformed = await handler(request('/v1/bays/report', {
    method: 'POST',
    body: '{not json',
  }))
  assertEquals(malformed.status, 400)
  const empty = await handler(request('/v1/bays/report', {
    method: 'POST',
    body: JSON.stringify({ channels: [] }),
  }))
  assertEquals(empty.status, 400)
})

Deno.test('bays report passes an rpc error name through', async () => {
  const handler = createHandler(await authorised({
    report: () => Promise.reject(new Error('ChannelLimitError')),
  }))
  const response = await handler(request('/v1/bays/report', {
    method: 'POST',
    body: JSON.stringify({ channels: CHANNELS }),
  }))
  assertEquals(response.status, 400)
  assertEquals((await response.json()).message, 'ChannelLimitError')
})

Deno.test('bays firmware answers the manifest or 204', async () => {
  const handler = createHandler(await authorised({
    firmware: () => Promise.resolve({
      version: '1.0.1',
      sha256: 'e'.repeat(64),
      size_bytes: 2048,
      secure_version: 1,
      storage_path: 'sensor_hub/1.0.1.bin',
    }),
  }))
  const response = await handler(request('/v1/bays/firmware?current=1.0.0'))
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.image_path, '/v1/bays/firmware/1.0.1/image')
  const none = await createHandler(await authorised())(
    request('/v1/bays/firmware?current=1.0.1'),
  )
  assertEquals(none.status, 204)
})

Deno.test('bays image streams a released version only', async () => {
  const handler = createHandler(await authorised({
    image: () => Promise.resolve(new Uint8Array([9, 8, 7])),
  }))
  const response = await handler(request('/v1/bays/firmware/1.0.1/image'))
  assertEquals(response.status, 200)
  assertEquals(new Uint8Array(await response.arrayBuffer()).length, 3)
  assertEquals(
    (await handler(request('/v1/bays/firmware/../x/image'))).status,
    404,
  )
})

Deno.test('camera and barrier devices get 403 on the bay routes', async () => {
  for (const kind of ['camera', 'barrier']) {
    const handler = createHandler(await authorised({ kind }))
    assertEquals((await handler(request('/v1/bays/config'))).status, 403)
    assertEquals(
      (await handler(request('/v1/bays/report', {
        method: 'POST',
        body: JSON.stringify({ channels: CHANNELS }),
      }))).status,
      403,
    )
    assertEquals((await handler(request('/v1/bays/firmware'))).status, 403)
  }
})

Deno.test('bay responses add no CORS headers', async () => {
  const handler = createHandler(await authorised())
  const response = await handler(request('/v1/bays/config'))
  assertEquals(response.headers.get('access-control-allow-origin'), null)
})
