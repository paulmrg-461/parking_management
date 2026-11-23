import { assertEquals } from 'jsr:@std/assert@^1'
import { createHandler, type GatewayDeps } from './index.ts'

const KEY = 'pkd_3fa94c0b12de_' + 'a'.repeat(64)

async function hash(): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(KEY))
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

function deps(options: {
  kind?: string
  key_hash?: string
  upload?: (path: string, bytes: Uint8Array) => Promise<{ status: number }>
  attach?: (deviceId: number, eventId: number, path: string) => Promise<Record<string, unknown>>
  read?: (deviceId: number, body: Record<string, unknown>) => Promise<Record<string, unknown>>
  config?: (deviceId: number) => Promise<Record<string, unknown>>
  removed?: string[]
} = {}): GatewayDeps {
  return {
    serviceKey: () => 'service',
    lookup: () => Promise.resolve({ id: 7, key_hash: options.key_hash ?? '' }),
    accept: () => Promise.resolve({
      ok: true, device_id: 7, lot_id: 1, kind: options.kind ?? 'camera', name: 'Cam',
    }),
    heartbeat: () => Promise.resolve({ heartbeat_interval_s: 60 }),
    authFailure: () => Promise.resolve(),
    now: () => new Date('2026-11-18T12:00:00Z'),
    lpr: {
      config: options.config ?? (() => Promise.resolve({ direction: 'entry' })),
      read: options.read ?? (() => Promise.resolve({ read_id: 1, outcome: 'recorded' })),
      attach: options.attach ?? (() => Promise.resolve({ event_id: 1, session_id: null })),
      upload: options.upload ?? (() => Promise.resolve({ status: 200 })),
      remove: (path) => {
        options.removed?.push(path)
        return Promise.resolve()
      },
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
      config: () => Promise.resolve({
        report_interval_s: 60,
        stable_ms: 5000,
        channels: [],
      }),
      report: () => Promise.resolve({
        accepted: 1,
        ignored: 0,
        created_channels: [1],
      }),
      firmware: () => Promise.resolve(null),
      image: () => Promise.resolve(null),
    },
  }
}

const headers = () => ({
  'X-Device-Key': KEY,
  'X-Device-Seq': '1',
  'X-Device-Timestamp': '1763467200',
})

const readsRequest = (body: unknown, idempotency?: string) => {
  const text = typeof body === 'string' ? body : JSON.stringify(body)
  const ref = typeof body === 'object' && body !== null
    ? String((body as Record<string, unknown>).client_ref ?? '')
    : ''
  return new Request('https://fn.test/functions/v1/device-gateway/v1/lpr/reads', {
    method: 'POST',
    headers: {
      ...headers(),
      'Content-Type': 'application/json',
      'Idempotency-Key': idempotency ?? ref,
    },
    body: text,
  })
}

const configRequest = () => new Request(
  'https://fn.test/functions/v1/device-gateway/v1/lpr/config',
  { headers: headers() },
)

const jpeg = (size = 4) => {
  const bytes = new Uint8Array(size)
  bytes.set([0xFF, 0xD8, 0xFF])
  return bytes
}

const snapshotRequest = (id = '42', bytes = jpeg(), type = 'image/jpeg') =>
  new Request(
    `https://fn.test/functions/v1/device-gateway/v1/lpr/events/${id}/snapshot`,
    { method: 'PUT', headers: { ...headers(), 'Content-Type': type }, body: bytes },
  )

Deno.test('lpr config returns the camera direction', async () => {
  const response = await createHandler(deps({ key_hash: await hash() }))(configRequest())
  assertEquals(response.status, 200)
  assertEquals((await response.json()).direction, 'entry')
})

Deno.test('lpr reads calls the ingest RPC and returns its outcome', async () => {
  let received: Record<string, unknown> = {}
  const handler = createHandler(deps({
    key_hash: await hash(),
    read: (_device, body) => {
      received = body as Record<string, unknown>
      return Promise.resolve({ read_id: 9, outcome: 'decided' })
    },
  }))
  const ref = '0b6f6d5c-3d4e-4a53-9a0e-2f7d1a2b9c11'
  const response = await handler(readsRequest({
    client_ref: ref,
    plate: 'ABC123',
    confidence: 0.95,
    captured_at: '2026-11-10T14:03:21Z',
    track_id: 't-1',
  }))
  assertEquals(response.status, 200)
  assertEquals((await response.json()).outcome, 'decided')
  assertEquals(received.client_ref, ref)
  assertEquals(received.plate, 'ABC123')
  assertEquals(received.track_id, 't-1')
})

Deno.test('lpr reads requires the idempotency header to match client_ref', async () => {
  const handler = createHandler(deps({ key_hash: await hash() }))
  const response = await handler(readsRequest({
    client_ref: '0b6f6d5c-3d4e-4a53-9a0e-2f7d1a2b9c11',
    plate: 'ABC123',
    confidence: 0.95,
    captured_at: '2026-11-10T14:03:21Z',
  }, 'another-uuid'))
  assertEquals(response.status, 400)
  assertEquals((await response.json()).message, 'InvalidDataError')
})

Deno.test('lpr reads rejects a body over 4 KiB', async () => {
  const handler = createHandler(deps({ key_hash: await hash() }))
  const response = await handler(readsRequest('x'.repeat(5000)))
  assertEquals(response.status, 413)
  assertEquals((await response.json()).message, 'PayloadTooLargeError')
})

Deno.test('lpr snapshot uploads and attaches using the device path', async () => {
  let uploaded: { path: string; size: number } = { path: '', size: 0 }
  let attached: { deviceId: number; eventId: number; path: string } | null = null
  const handler = createHandler(deps({
    key_hash: await hash(),
    upload: (path, bytes) => {
      uploaded = { path, size: bytes.length }
      return Promise.resolve({ status: 200 })
    },
    attach: (deviceId, eventId, path) => {
      attached = { deviceId, eventId, path }
      return Promise.resolve({ event_id: eventId, session_id: 5 })
    },
  }))
  const response = await handler(snapshotRequest('42'))
  assertEquals(response.status, 200)
  assertEquals(uploaded.path, 'lpr/1/7/42.jpg')
  assertEquals(uploaded.size, 4)
  assertEquals(attached, { deviceId: 7, eventId: 42, path: 'lpr/1/7/42.jpg' })
})

Deno.test('lpr snapshot rejects a non-jpeg and a wrong magic header', async () => {
  const handler = createHandler(deps({ key_hash: await hash() }))
  assertEquals((await handler(snapshotRequest('42', jpeg(), 'text/plain'))).status, 400)
  const wrong = new Uint8Array([1, 2, 3, 4])
  assertEquals((await handler(snapshotRequest('42', wrong))).status, 400)
})

Deno.test('lpr snapshot rejects a body over 256 KiB', async () => {
  const handler = createHandler(deps({ key_hash: await hash() }))
  const response = await handler(snapshotRequest('42', jpeg(262145)))
  assertEquals(response.status, 413)
})

Deno.test('lpr snapshot treats a storage 409 as already attached', async () => {
  let attached = false
  const handler = createHandler(deps({
    key_hash: await hash(),
    upload: () => Promise.resolve({ status: 409 }),
    attach: () => {
      attached = true
      return Promise.resolve({})
    },
  }))
  const response = await handler(snapshotRequest('42'))
  assertEquals(response.status, 409)
  assertEquals((await response.json()).message, 'SnapshotAlreadyAttachedError')
  assertEquals(attached, false)
})

Deno.test('lpr snapshot deletes the object when the attach is refused', async () => {
  const removed: string[] = []
  const handler = createHandler(deps({
    key_hash: await hash(),
    removed,
    attach: () => Promise.reject(new Error('LprEventNotFoundError')),
  }))
  const response = await handler(snapshotRequest('42'))
  assertEquals(response.status, 404)
  assertEquals(removed, ['lpr/1/7/42.jpg'])
})

Deno.test('lpr snapshot passes an rpc error name through', async () => {
  const handler = createHandler(deps({
    key_hash: await hash(),
    read: () => Promise.reject(new Error('InvalidPlateError')),
  }))
  const response = await handler(readsRequest({
    client_ref: '0b6f6d5c-3d4e-4a53-9a0e-2f7d1a2b9c11',
    plate: 'bad',
    confidence: 0.95,
    captured_at: '2026-11-10T14:03:21Z',
  }))
  assertEquals(response.status, 400)
  assertEquals((await response.json()).message, 'InvalidPlateError')
})

Deno.test('lpr snapshot only matches an integer event id', async () => {
  const handler = createHandler(deps({ key_hash: await hash() }))
  assertEquals((await handler(snapshotRequest('abc'))).status, 404)
})

Deno.test('a barrier gets 403 on all three lpr routes', async () => {
  const handler = createHandler(deps({ key_hash: await hash(), kind: 'barrier' }))
  assertEquals((await handler(configRequest())).status, 403)
  assertEquals((await handler(readsRequest({
    client_ref: '0b6f6d5c-3d4e-4a53-9a0e-2f7d1a2b9c11',
    plate: 'ABC123',
    confidence: 0.95,
    captured_at: '2026-11-10T14:03:21Z',
  }))).status, 403)
  assertEquals((await handler(snapshotRequest('42'))).status, 403)
})
