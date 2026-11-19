import { assertEquals } from 'jsr:@std/assert@^1'
import { createHandler, type GatewayDeps } from './index.ts'
import { SigningUnavailableError, type SignableCommand } from './signing.ts'

const KEY = 'pkd_3fa94c0b12de_' + 'a'.repeat(64)
const COMMAND_ID = '6f1c1d8e-0b34-4d44-8a3e-6f5c1c1d9a10'

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
  signer?: () => Promise<{ publicKey: string; sign: (command: SignableCommand) => Promise<string> }>
  next?: () => Promise<Record<string, unknown> | null>
  config?: () => Promise<Record<string, unknown>>
  ack?: (
    deviceId: number,
    commandId: string,
    result: string,
    detail: Record<string, unknown>,
  ) => Promise<Record<string, unknown>>
  event?: (
    deviceId: number,
    clientRef: string,
    event: string,
    at: string,
    detail: Record<string, unknown>,
  ) => Promise<Record<string, unknown>>
  firmware?: () => Promise<Record<string, unknown> | null>
  image?: () => Promise<Uint8Array | null>
  slept?: number[]
} = {}): GatewayDeps {
  const slept = options.slept ?? []
  return {
    serviceKey: () => 'service',
    lookup: () => Promise.resolve({ id: 7, key_hash: '' }),
    accept: () => Promise.resolve({
      ok: true,
      device_id: 7,
      lot_id: 1,
      kind: options.kind ?? 'barrier',
      name: 'B1',
    }),
    heartbeat: () => Promise.resolve({}),
    authFailure: () => Promise.resolve(),
    now: () => new Date('2026-11-18T12:00:00Z'),
    lpr: {
      config: () => Promise.resolve({}),
      read: () => Promise.resolve({}),
      attach: () => Promise.resolve({}),
      upload: () => Promise.resolve({ status: 200 }),
      remove: () => Promise.resolve(),
    },
    barrier: {
      config: options.config ?? (() => Promise.resolve({
        direction: 'exit',
        open_hold_ms: 1200,
        max_open_seconds: 25,
        post_clear_delay_ms: 1500,
        max_reversals: 3,
        command_ttl_seconds: 30,
      })),
      next: options.next ?? (() => Promise.resolve(null)),
      ack: options.ack ?? (() => Promise.resolve({ status: 'executed' })),
      event: options.event ?? (() => Promise.resolve({ ok: true })),
      firmware: options.firmware ?? (() => Promise.resolve(null)),
      image: options.image ?? (() => Promise.resolve(null)),
      signer: options.signer ??
        (() => Promise.resolve({
          publicKey: '',
          sign: () => Promise.resolve('c2ln'),
        })),
      sleep: (ms) => {
        slept.push(ms)
        return Promise.resolve()
      },
    },
  }
}

async function authorised(
  options: Parameters<typeof deps>[0] & { key_hash?: string } = {},
): Promise<GatewayDeps> {
  const base = deps(options)
  const keyHash = options.key_hash ?? await hash()
  return { ...base, lookup: () => Promise.resolve({ id: 7, key_hash: keyHash }) }
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

Deno.test('barrier config maps the firmware timings', async () => {
  const handler = createHandler(await authorised())
  const response = await handler(request('/v1/barrier/config'))
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.direction, 'exit')
  assertEquals(body.open_hold_ms, 1200)
  assertEquals(body.max_open_s, 25)
  assertEquals(body.command_ttl_s, 30)
  assertEquals(body.poll_wait_s, 20)
})

Deno.test('barrier next signs the command with the config timings', async () => {
  const captured: { command?: SignableCommand } = {}
  const handler = createHandler(await authorised({
    next: () => Promise.resolve({
      id: COMMAND_ID,
      device_id: 7,
      issued_at: '2026-11-18T11:59:00Z',
      expires_at: '2026-11-18T11:59:30Z',
      nonce: '9f2c4a7e1b3d5f60718293a4b5c6d7e8',
      status: 'delivered',
    }),
    signer: () => Promise.resolve({
      publicKey: '',
      sign: (command) => {
        captured.command = command
        return Promise.resolve('c2lnbmF0dXJl')
      },
    }),
  }))
  const response = await handler(request('/v1/barrier/commands/next?wait=0'))
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.command.id, COMMAND_ID)
  assertEquals(body.command.issued_at, 1795003140)
  assertEquals(body.command.expires_at, 1795003170)
  assertEquals(body.command.hold_ms, 1200)
  assertEquals(body.command.max_open_s, 25)
  assertEquals(body.command.signature, 'c2lnbmF0dXJl')
  assertEquals(body.server_time, '2026-11-18T12:00:00.000Z')
  assertEquals(captured.command?.nonce, '9f2c4a7e1b3d5f60718293a4b5c6d7e8')
})

Deno.test('barrier next returns 204 after the wait', async () => {
  const slept: number[] = []
  const handler = createHandler(await authorised({ slept }))
  const response = await handler(request('/v1/barrier/commands/next?wait=1'))
  assertEquals(response.status, 204)
  // wait=1 -> two attempts of 500 ms, one sleep.
  assertEquals(slept.length, 1)
})

Deno.test('barrier next clamps a long wait to 20 s', async () => {
  const slept: number[] = []
  const handler = createHandler(await authorised({ slept }))
  const response = await handler(request('/v1/barrier/commands/next?wait=999'))
  assertEquals(response.status, 204)
  assertEquals(slept.length, 39)
})

Deno.test('barrier next fails closed without a signing key', async () => {
  const handler = createHandler(await authorised({
    signer: () => Promise.reject(new SigningUnavailableError()),
  }))
  const response = await handler(request('/v1/barrier/commands/next'))
  assertEquals(response.status, 503)
  assertEquals((await response.json()).message, 'GatewayUnavailableError')
})

Deno.test('barrier ack passes the result and idempotency', async () => {
  let received: Record<string, unknown> = {}
  const handler = createHandler(await authorised({
    ack: (deviceId, commandId, result, detail) => {
      received = { deviceId, commandId, result, detail }
      return Promise.resolve({ status: 'executed' })
    },
  }))
  const response = await handler(request(
    `/v1/barrier/commands/${COMMAND_ID}/ack`,
    {
      method: 'POST',
      headers: { 'Idempotency-Key': COMMAND_ID },
      body: JSON.stringify({ result: 'opened', open_ms: 4210 }),
    },
  ))
  assertEquals(response.status, 200)
  assertEquals((await response.json()).status, 'executed')
  assertEquals(received['commandId'], COMMAND_ID)
  assertEquals(received['result'], 'opened')
  assertEquals((received['detail'] as Record<string, unknown>)['open_ms'], 4210)
  assertEquals(
    (received['detail'] as Record<string, unknown>)['result'],
    undefined,
  )
})

Deno.test('barrier ack validates the key, the id and the result', async () => {
  const handler = createHandler(await authorised())
  const mismatch = await handler(request(
    `/v1/barrier/commands/${COMMAND_ID}/ack`,
    {
      method: 'POST',
      headers: { 'Idempotency-Key': 'other' },
      body: JSON.stringify({ result: 'opened' }),
    },
  ))
  assertEquals(mismatch.status, 400)
  const badResult = await handler(request(
    `/v1/barrier/commands/${COMMAND_ID}/ack`,
    {
      method: 'POST',
      headers: { 'Idempotency-Key': COMMAND_ID },
      body: JSON.stringify({ result: 'maybe' }),
    },
  ))
  assertEquals(badResult.status, 400)
  const badId = await handler(request('/v1/barrier/commands/abc/ack', {
    method: 'POST',
    headers: { 'Idempotency-Key': 'abc' },
    body: JSON.stringify({ result: 'opened' }),
  }))
  assertEquals(badId.status, 404)
})

Deno.test('barrier ack maps a foreign command to 404', async () => {
  const handler = createHandler(await authorised({
    ack: () => Promise.reject(new Error('BarrierCommandNotFoundError')),
  }))
  const response = await handler(request(
    `/v1/barrier/commands/${COMMAND_ID}/ack`,
    {
      method: 'POST',
      headers: { 'Idempotency-Key': COMMAND_ID },
      body: JSON.stringify({ result: 'opened' }),
    },
  ))
  assertEquals(response.status, 404)
})

Deno.test('barrier events are validated and accepted', async () => {
  let received: Record<string, unknown> = {}
  const handler = createHandler(await authorised({
    event: (deviceId, clientRef, event, at, detail) => {
      received = { deviceId, clientRef, event, at, detail }
      return Promise.resolve({ ok: true })
    },
  }))
  const reference = '0b6f6d5c-3d4e-4a53-9a0e-2f7d1a2b9c11'
  const response = await handler(request('/v1/barrier/events', {
    method: 'POST',
    body: JSON.stringify({
      client_ref: reference,
      event: 'tamper',
      at: '2026-11-10T14:03:21Z',
      detail: { input: 'enclosure' },
    }),
  }))
  assertEquals(response.status, 200)
  assertEquals((await response.json()).ok, true)
  assertEquals(received['event'], 'tamper')
  assertEquals(received['clientRef'], reference)
})

Deno.test('barrier events reject a bad reference and an unknown type', async () => {
  const handler = createHandler(await authorised({
    event: () => Promise.reject(new Error('InvalidDataError')),
  }))
  const badRef = await handler(request('/v1/barrier/events', {
    method: 'POST',
    body: JSON.stringify({ client_ref: 'x', event: 'tamper', at: 'now' }),
  }))
  assertEquals(badRef.status, 400)
  const unknown = await handler(request('/v1/barrier/events', {
    method: 'POST',
    body: JSON.stringify({
      client_ref: '0b6f6d5c-3d4e-4a53-9a0e-2f7d1a2b9c11',
      event: 'exploded',
      at: '2026-11-10T14:03:21Z',
    }),
  }))
  assertEquals(unknown.status, 400)
})

Deno.test('barrier firmware answers the manifest or 204', async () => {
  const manifest = {
    version: '1.1.0',
    sha256: 'c'.repeat(64),
    size_bytes: 1048576,
    secure_version: 2,
    storage_path: 'barrier/1.1.0.bin',
  }
  const handler = createHandler(await authorised({
    firmware: () => Promise.resolve(manifest),
  }))
  const response = await handler(request('/v1/barrier/firmware?current=1.0.0'))
  assertEquals(response.status, 200)
  const body = await response.json()
  assertEquals(body.version, '1.1.0')
  assertEquals(body.image_path, '/v1/barrier/firmware/1.1.0/image')

  const current = createHandler(await authorised())
  const none = await current(request('/v1/barrier/firmware?current=1.1.0'))
  assertEquals(none.status, 204)
})

Deno.test('barrier image streams a released version only', async () => {
  const handler = createHandler(await authorised({
    image: () => Promise.resolve(new Uint8Array([1, 2, 3])),
  }))
  const response = await handler(request('/v1/barrier/firmware/1.1.0/image'))
  assertEquals(response.status, 200)
  assertEquals(response.headers.get('Content-Type'), 'application/octet-stream')
  assertEquals(new Uint8Array(await response.arrayBuffer()).length, 3)

  const invalid = await handler(request('/v1/barrier/firmware/../x/image'))
  assertEquals(invalid.status, 404)
  const missing = createHandler(await authorised())
  assertEquals(
    (await missing(request('/v1/barrier/firmware/9.9.9/image'))).status,
    404,
  )
})

Deno.test('a camera gets 403 on every barrier route', async () => {
  const handler = createHandler(await authorised({ kind: 'camera' }))
  for (const [path, init] of [
    ['/v1/barrier/config', {}],
    ['/v1/barrier/commands/next', {}],
    [`/v1/barrier/commands/${COMMAND_ID}/ack`, {
      method: 'POST',
      headers: { 'Idempotency-Key': COMMAND_ID },
      body: JSON.stringify({ result: 'opened' }),
    }],
    ['/v1/barrier/events', {
      method: 'POST',
      body: JSON.stringify({}),
    }],
    ['/v1/barrier/firmware', {}],
    ['/v1/barrier/firmware/1.0.0/image', {}],
  ] as Array<[string, RequestInit]>) {
    const response = await handler(request(path, init))
    assertEquals(response.status, 403, path)
  }
})
