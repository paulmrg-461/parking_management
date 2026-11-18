// Device gateway: the only path a hardware device uses. It never accepts a
// user JWT. The device sends its key, a strictly increasing sequence and a
// timestamp; the gateway hashes the key, compares it with the stored hash in
// constant time, then delegates the protocol checks to the service-role RPCs.
//
// This change ships /v1/time and /v1/heartbeat. Camera/barrier/sensor routes
// are added by the follow-up hardware changes.

import { json } from '../_shared/ai/sse.ts'

export type GatewayDeps = {
  serviceKey: () => string
  lookup: (prefix: string) => Promise<{ id: number; key_hash: string } | null>
  accept: (
    deviceId: number,
    seq: number,
    sentAt: string,
    firmware: string | null,
  ) => Promise<Record<string, unknown>>
  heartbeat: (
    deviceId: number,
    status: Record<string, unknown>,
  ) => Promise<Record<string, unknown>>
  authFailure: (deviceId: number) => Promise<void>
  now: () => Date
}

const KEY = /^pkd_([0-9a-f]{12})_([0-9a-f]{64})$/

function hex(bytes: ArrayBuffer): string {
  return [...new Uint8Array(bytes)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

async function sha256(value: string): Promise<string> {
  return hex(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))
}

function equal(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return diff === 0
}

function refuse(error: string, status: number): Response {
  return json({ message: error }, status)
}

export function createHandler(deps: GatewayDeps) {
  return async (req: Request): Promise<Response> => {
    const url = new URL(req.url)
    if (req.method === 'GET' && url.pathname.endsWith('/v1/time')) {
      return json({
        server_time: deps.now().toISOString(),
        max_skew_s: 300,
      })
    }
    if (!(req.method === 'POST' && url.pathname.endsWith('/v1/heartbeat'))) {
      return refuse('NotFound', 404)
    }
    if (deps.serviceKey() === '') {
      return refuse('DeviceUnauthorizedError', 401)
    }

    const key = req.headers.get('X-Device-Key') ?? ''
    const match = KEY.exec(key)
    if (!match) {
      return refuse('DeviceUnauthorizedError', 401)
    }
    const prefix = match[1]
    const lookup = await deps.lookup(prefix)
    if (!lookup) {
      return refuse('DeviceUnauthorizedError', 401)
    }
    const hash = await sha256(key)
    if (!equal(hash, lookup.key_hash)) {
      await deps.authFailure(lookup.id)
      return refuse('DeviceUnauthorizedError', 401)
    }

    const seq = Number(req.headers.get('X-Device-Seq') ?? '')
    const sentAt = req.headers.get('X-Device-Timestamp') ?? ''
    const firmware = req.headers.get('X-Device-Firmware')
    const accepted = await deps.accept(
      lookup.id,
      Number.isSafeInteger(seq) ? seq : NaN,
      sentAt === '' ? '' : new Date(Number(sentAt) * 1000).toISOString(),
      firmware,
    )
    if (accepted.ok !== true) {
      const error = String(accepted.error ?? 'DeviceUnauthorizedError')
      const status = error === 'DeviceRateLimitedError'
        ? 429
        : error === 'DeviceReplayError'
        ? 409
        : error === 'DeviceClockSkewError'
        ? 400
        : 401
      return json(accepted, status)
    }

    let status: Record<string, unknown> = {}
    try {
      const body = await req.json() as Record<string, unknown>
      if (body && typeof body.status === 'object' && body.status !== null) {
        status = body.status as Record<string, unknown>
      }
    } catch (_) {
      status = {}
    }
    const heartbeat = await deps.heartbeat(lookup.id, status)
    return json({
      ...heartbeat,
      device: {
        id: accepted.device_id,
        lot_id: accepted.lot_id,
        kind: accepted.kind,
        name: accepted.name,
      },
    })
  }
}

function realDeps(): GatewayDeps {
  const url = Deno.env.get('SUPABASE_URL') ?? ''
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const rpc = async (name: string, body: Record<string, unknown>) => {
    const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
      method: 'POST',
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    })
    if (!response.ok) throw new Error('ServiceError')
    const text = await response.text()
    return text ? JSON.parse(text) : null
  }
  return {
    serviceKey: () => key,
    lookup: (prefix) => rpc('device_lookup', { p_key_prefix: prefix }),
    accept: (deviceId, seq, sentAt, firmware) =>
      rpc('device_accept_request', {
        p_device_id: deviceId,
        p_seq: seq,
        p_sent_at: sentAt,
        p_firmware: firmware,
      }),
    heartbeat: (deviceId, status) =>
      rpc('device_heartbeat', { p_device_id: deviceId, p_status: status }),
    authFailure: async (deviceId) => {
      await rpc('device_record_auth_failure', { p_device_id: deviceId })
    },
    now: () => new Date(),
  }
}

if (import.meta.main) {
  Deno.serve(createHandler(realDeps()))
}
