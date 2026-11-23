// Device gateway: the only path a hardware device uses. It never accepts a
// user JWT. The device sends its key, a strictly increasing sequence and a
// timestamp; the gateway hashes the key, compares it with the stored hash in
// constant time, then delegates the protocol checks to the service-role RPCs.
//
// This change ships /v1/time and /v1/heartbeat. Camera/barrier/sensor routes
// are added by the follow-up hardware changes.

import { json } from '../_shared/ai/sse.ts'
import { matchRoute } from './routing.ts'
import {
  createSigner,
  SigningUnavailableError,
  type BarrierSigner,
} from './signing.ts'

export type LprReadBody = {
  client_ref: string
  plate: string
  confidence: number
  captured_at: string
  track_id: string | null
}

export type LprDeps = {
  config: (deviceId: number) => Promise<Record<string, unknown>>
  read: (
    deviceId: number,
    body: LprReadBody,
  ) => Promise<Record<string, unknown>>
  attach: (
    deviceId: number,
    eventId: number,
    path: string,
  ) => Promise<Record<string, unknown>>
  upload: (path: string, bytes: Uint8Array) => Promise<{ status: number }>
  remove: (path: string) => Promise<void>
}

export type BarrierDeps = {
  config: (deviceId: number) => Promise<Record<string, unknown>>
  next: (deviceId: number) => Promise<Record<string, unknown> | null>
  ack: (
    deviceId: number,
    commandId: string,
    result: string,
    detail: Record<string, unknown>,
  ) => Promise<Record<string, unknown>>
  event: (
    deviceId: number,
    clientRef: string,
    event: string,
    at: string,
    detail: Record<string, unknown>,
  ) => Promise<Record<string, unknown>>
  firmware: (
    deviceId: number,
    current: string | null,
  ) => Promise<Record<string, unknown> | null>
  image: (version: string) => Promise<Uint8Array | null>
  signer: () => Promise<BarrierSigner>
  sleep: (ms: number) => Promise<void>
}

export type BaysDeps = {
  config: (deviceId: number) => Promise<Record<string, unknown>>
  report: (
    deviceId: number,
    channels: unknown,
    full: boolean,
  ) => Promise<Record<string, unknown>>
  firmware: (
    deviceId: number,
    current: string | null,
  ) => Promise<Record<string, unknown> | null>
  image: (version: string) => Promise<Uint8Array | null>
}

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
  lpr: LprDeps
  barrier: BarrierDeps
  bays: BaysDeps
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
  const encoder = new TextEncoder()
  const UUID =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

  function failure(error: unknown): Response {
    const code = error instanceof Error ? error.message : 'ServiceError'
    const status = code === 'InvalidDeviceKindError'
      ? 403
      : code === 'LprEventNotFoundError' ||
          code === 'BarrierCommandNotFoundError' ||
          code === 'NotFoundError'
      ? 404
      : code === 'SnapshotAlreadyAttachedError'
      ? 409
      : code === 'GatewayUnavailableError'
      ? 503
      : code === 'InvalidPlateError' || code === 'InvalidConfidenceError' ||
          code === 'InvalidReadTimeError' ||
          code === 'LprDirectionNotSetError' ||
          code === 'InvalidSnapshotPathError' || code === 'InvalidDataError' ||
          code === 'ChannelLimitError'
      ? 400
      : 502
    return refuse(code, status)
  }

  async function reads(req: Request, deviceId: number): Promise<Response> {
    const text = await req.text()
    if (encoder.encode(text).length > 4096) {
      return refuse('PayloadTooLargeError', 413)
    }
    let body: Record<string, unknown>
    try {
      body = JSON.parse(text) as Record<string, unknown>
    } catch (_) {
      return refuse('InvalidDataError', 400)
    }
    const clientRef = String(body.client_ref ?? '')
    if (!UUID.test(clientRef) ||
        (req.headers.get('Idempotency-Key') ?? '') !== clientRef) {
      return refuse('InvalidDataError', 400)
    }
    const plate = String(body.plate ?? '')
    const confidence = Number(body.confidence)
    const capturedAt = String(body.captured_at ?? '')
    if (plate === '' || !Number.isFinite(confidence) || capturedAt === '') {
      return refuse('InvalidDataError', 400)
    }
    const track = body.track_id === undefined || body.track_id === null
      ? null
      : String(body.track_id)
    try {
      return json(await deps.lpr.read(deviceId, {
        client_ref: clientRef,
        plate,
        confidence,
        captured_at: capturedAt,
        track_id: track,
      }))
    } catch (error) {
      return failure(error)
    }
  }

  async function snapshot(
    req: Request,
    deviceId: number,
    lotId: number,
    eventIdRaw: string,
  ): Promise<Response> {
    if (!/^\d{1,18}$/.test(eventIdRaw)) {
      return refuse('NotFound', 404)
    }
    const eventId = Number(eventIdRaw)
    const type = (req.headers.get('Content-Type') ?? '').toLowerCase()
    if (!type.startsWith('image/jpeg')) {
      return refuse('InvalidDataError', 400)
    }
    const declared = Number(req.headers.get('Content-Length') ?? '0')
    if (Number.isFinite(declared) && declared > 262144) {
      return refuse('PayloadTooLargeError', 413)
    }
    const bytes = new Uint8Array(await req.arrayBuffer())
    if (bytes.length > 262144) {
      return refuse('PayloadTooLargeError', 413)
    }
    if (bytes.length < 3 || bytes[0] !== 0xFF || bytes[1] !== 0xD8 ||
        bytes[2] !== 0xFF) {
      return refuse('InvalidDataError', 400)
    }
    // The path is derived from the authenticated device, never from the body.
    const path = `lpr/${lotId}/${deviceId}/${eventId}.jpg`
    const upload = await deps.lpr.upload(path, bytes)
    if (upload.status === 409) {
      return refuse('SnapshotAlreadyAttachedError', 409)
    }
    if (upload.status < 200 || upload.status >= 300) {
      return refuse('AiUpstreamError', 502)
    }
    try {
      return json(await deps.lpr.attach(deviceId, eventId, path))
    } catch (error) {
      const code = error instanceof Error ? error.message : 'ServiceError'
      if (code !== 'SnapshotAlreadyAttachedError') {
        try {
          await deps.lpr.remove(path)
        } catch (_) {
          // The janitor will pick up an orphan later.
        }
      }
      return failure(error)
    }
  }


  const BARRIER_VERSION = /^\d+\.\d+\.\d+$/
  const polling = new Set<number>()
  const sleep = (ms: number) => deps.barrier.sleep(ms)

  function unixSeconds(value: unknown): number {
    if (typeof value === 'number') return Math.trunc(value)
    const parsed = Date.parse(String(value))
    return Number.isFinite(parsed) ? Math.floor(parsed / 1000) : NaN
  }

  async function readJson(
    req: Request,
    limit: number,
  ): Promise<Record<string, unknown> | Response> {
    const text = await req.text()
    if (encoder.encode(text).length > limit) {
      return refuse('PayloadTooLargeError', 413)
    }
    try {
      const body = JSON.parse(text)
      if (body === null || typeof body !== 'object' || Array.isArray(body)) {
        return refuse('InvalidDataError', 400)
      }
      return body as Record<string, unknown>
    } catch (_) {
      return refuse('InvalidDataError', 400)
    }
  }

  async function barrierConfig(deviceId: number): Promise<Response> {
    try {
      const raw = await deps.barrier.config(deviceId)
      return json({
        direction: raw.direction,
        open_hold_ms: Number(raw.open_hold_ms),
        max_open_s: Number(raw.max_open_seconds),
        post_clear_delay_ms: Number(raw.post_clear_delay_ms),
        max_reversals: Number(raw.max_reversals),
        command_ttl_s: Number(raw.command_ttl_seconds),
        poll_wait_s: 20,
        heartbeat_interval_s: 60,
      })
    } catch (error) {
      return failure(error)
    }
  }

  async function barrierNext(
    url: URL,
    deviceId: number,
  ): Promise<Response> {
    let signer: BarrierSigner
    try {
      signer = await deps.barrier.signer()
    } catch (error) {
      if (error instanceof SigningUnavailableError) {
        return refuse('GatewayUnavailableError', 503)
      }
      return failure(error)
    }
    const raw = Number(url.searchParams.get('wait') ?? '20')
    const wait = Math.min(Math.max(Number.isFinite(raw) ? raw : 20, 0), 20)
    if (polling.has(deviceId)) {
      return refuse('BarrierPollInProgressError', 409)
    }
    polling.add(deviceId)
    try {
      const attempts = Math.max(1, Math.ceil((wait * 1000) / 500))
      for (let attempt = 0; attempt < attempts; attempt++) {
        const command = await deps.barrier.next(deviceId)
        if (command !== null) {
          const config = await deps.barrier.config(deviceId)
          const issuedAt = unixSeconds(command.issued_at)
          const expiresAt = unixSeconds(command.expires_at)
          const holdMs = Number(config.open_hold_ms)
          const maxOpenS = Number(config.max_open_seconds)
          const signature = await signer.sign({
            id: String(command.id),
            device_id: Number(command.device_id),
            issued_at: issuedAt,
            expires_at: expiresAt,
            nonce: String(command.nonce),
            hold_ms: holdMs,
            max_open_s: maxOpenS,
          })
          return json({
            command: {
              id: command.id,
              device_id: Number(command.device_id),
              action: 'open',
              issued_at: issuedAt,
              expires_at: expiresAt,
              nonce: command.nonce,
              hold_ms: holdMs,
              max_open_s: maxOpenS,
              signature,
            },
            server_time: deps.now().toISOString(),
          })
        }
        if (attempt < attempts - 1) await sleep(500)
      }
      return new Response(null, { status: 204 })
    } catch (error) {
      return failure(error)
    } finally {
      polling.delete(deviceId)
    }
  }

  async function barrierAck(
    req: Request,
    deviceId: number,
    commandId: string,
  ): Promise<Response> {
    if (!UUID.test(commandId)) {
      return refuse('BarrierCommandNotFoundError', 404)
    }
    if ((req.headers.get('Idempotency-Key') ?? '') !== commandId) {
      return refuse('InvalidDataError', 400)
    }
    const parsed = await readJson(req, 2048)
    if (parsed instanceof Response) return parsed
    const result = String(parsed.result ?? '')
    if (result !== 'opened' && result !== 'refused') {
      return refuse('InvalidDataError', 400)
    }
    const detail = { ...parsed }
    delete detail.result
    try {
      const ack = await deps.barrier.ack(deviceId, commandId, result, detail)
      return json({ status: ack.status })
    } catch (error) {
      return failure(error)
    }
  }

  async function barrierEvent(
    req: Request,
    deviceId: number,
  ): Promise<Response> {
    const parsed = await readJson(req, 2048)
    if (parsed instanceof Response) return parsed
    const clientRef = String(parsed.client_ref ?? '')
    const event = String(parsed.event ?? '')
    const at = String(parsed.at ?? '')
    if (!UUID.test(clientRef) || event === '' || at === '') {
      return refuse('InvalidDataError', 400)
    }
    const detail = typeof parsed.detail === 'object' && parsed.detail !== null
      ? parsed.detail as Record<string, unknown>
      : {}
    try {
      await deps.barrier.event(deviceId, clientRef, event, at, detail)
      return json({ ok: true })
    } catch (error) {
      return failure(error)
    }
  }

  async function barrierFirmware(
    url: URL,
    deviceId: number,
  ): Promise<Response> {
    try {
      const manifest = await deps.barrier.firmware(
        deviceId,
        url.searchParams.get('current'),
      )
      if (manifest === null) {
        return new Response(null, { status: 204 })
      }
      return json({
        version: manifest.version,
        sha256: manifest.sha256,
        size: Number(manifest.size_bytes),
        secure_version: Number(manifest.secure_version),
        image_path: `/v1/barrier/firmware/${manifest.version}/image`,
      })
    } catch (error) {
      return failure(error)
    }
  }

  async function barrierImage(version: string): Promise<Response> {
    if (!BARRIER_VERSION.test(version)) {
      return refuse('NotFoundError', 404)
    }
    try {
      const bytes = await deps.barrier.image(version)
      if (bytes === null) {
        return refuse('NotFoundError', 404)
      }
      const copy = new Uint8Array(new ArrayBuffer(bytes.length))
      copy.set(bytes)
      return new Response(copy.buffer, {
        status: 200,
        headers: { 'Content-Type': 'application/octet-stream' },
      })
    } catch (error) {
      return failure(error)
    }
  }


  async function baysConfig(deviceId: number): Promise<Response> {
    try {
      return json(await deps.bays.config(deviceId))
    } catch (error) {
      return failure(error)
    }
  }

  async function baysReport(
    req: Request,
    deviceId: number,
  ): Promise<Response> {
    const parsed = await readJson(req, 16384)
    if (parsed instanceof Response) return parsed
    const channels = parsed.channels
    if (!Array.isArray(channels) || channels.length === 0) {
      return refuse('InvalidDataError', 400)
    }
    const full = parsed.full === true
    try {
      return json(await deps.bays.report(deviceId, channels, full))
    } catch (error) {
      return failure(error)
    }
  }

  async function baysFirmware(
    url: URL,
    deviceId: number,
  ): Promise<Response> {
    try {
      const manifest = await deps.bays.firmware(
        deviceId,
        url.searchParams.get('current'),
      )
      if (manifest === null) {
        return new Response(null, { status: 204 })
      }
      return json({
        version: manifest.version,
        sha256: manifest.sha256,
        size: Number(manifest.size_bytes),
        secure_version: Number(manifest.secure_version),
        image_path: `/v1/bays/firmware/${manifest.version}/image`,
      })
    } catch (error) {
      return failure(error)
    }
  }

  async function baysImage(version: string): Promise<Response> {
    if (!BARRIER_VERSION.test(version)) {
      return refuse('NotFoundError', 404)
    }
    try {
      const bytes = await deps.bays.image(version)
      if (bytes === null) {
        return refuse('NotFoundError', 404)
      }
      const copy = new Uint8Array(new ArrayBuffer(bytes.length))
      copy.set(bytes)
      return new Response(copy.buffer, {
        status: 200,
        headers: { 'Content-Type': 'application/octet-stream' },
      })
    } catch (error) {
      return failure(error)
    }
  }

  return async (req: Request): Promise<Response> => {
    const url = new URL(req.url)
    const route = matchRoute(req.method, url.pathname)
    if (!route) {
      return refuse('NotFound', 404)
    }
    if (route.name === 'time') {
      return json({
        server_time: deps.now().toISOString(),
        max_skew_s: 300,
      })
    }
    if (deps.serviceKey() === '') {
      return refuse('DeviceUnauthorizedError', 401)
    }

    const key = req.headers.get('X-Device-Key') ?? ''
    const match = KEY.exec(key)
    if (!match) {
      return refuse('DeviceUnauthorizedError', 401)
    }
    const lookup = await deps.lookup(match[1])
    if (!lookup) {
      return refuse('DeviceUnauthorizedError', 401)
    }
    if (!equal(await sha256(key), lookup.key_hash)) {
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

    const deviceId = Number(accepted.device_id)
    if (route.name === 'heartbeat') {
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

    // LPR routes are camera-only, barrier routes barrier-only, bay routes
    // sensor-hub only.
    const requiredKind = route.name.startsWith('lpr_')
      ? 'camera'
      : route.name.startsWith('barrier_')
      ? 'barrier'
      : 'sensor_hub'
    if (accepted.kind !== requiredKind) {
      return refuse('InvalidDeviceKindError', 403)
    }
    if (route.name === 'bays_config') {
      return baysConfig(deviceId)
    }
    if (route.name === 'bays_report') {
      return baysReport(req, deviceId)
    }
    if (route.name === 'bays_firmware') {
      return baysFirmware(url, deviceId)
    }
    if (route.name === 'bays_image') {
      return baysImage(route.params['version'] ?? '')
    }
    if (route.name === 'barrier_config') {
      return barrierConfig(deviceId)
    }
    if (route.name === 'barrier_next') {
      return barrierNext(url, deviceId)
    }
    if (route.name === 'barrier_ack') {
      return barrierAck(req, deviceId, route.params['id'] ?? '')
    }
    if (route.name === 'barrier_event') {
      return barrierEvent(req, deviceId)
    }
    if (route.name === 'barrier_firmware') {
      return barrierFirmware(url, deviceId)
    }
    if (route.name === 'barrier_image') {
      return barrierImage(route.params['version'] ?? '')
    }
    if (route.name === 'lpr_config') {
      try {
        return json(await deps.lpr.config(deviceId))
      } catch (error) {
        return failure(error)
      }
    }
    if (route.name === 'lpr_reads') {
      return reads(req, deviceId)
    }
    return snapshot(req, deviceId, Number(accepted.lot_id),
      route.params['id'] ?? '')
  }
}

function realDeps(): GatewayDeps {
  const url = Deno.env.get('SUPABASE_URL') ?? ''
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  let signerPromise: Promise<BarrierSigner> | null = null
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
    const text = await response.text()
    if (!response.ok) {
      let code = 'ServiceError'
      try {
        const parsed = JSON.parse(text) as Record<string, unknown>
        code = String(parsed.message ?? parsed.error ?? code)
      } catch (_) {
        // keep the generic code
      }
      throw new Error(code)
    }
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
    lpr: {
      config: (deviceId) => rpc('device_lpr_config', { p_device_id: deviceId }),
      read: (deviceId, body) => rpc('device_ingest_lpr_read', {
        p_device_id: deviceId,
        p_client_ref: body.client_ref,
        p_plate: body.plate,
        p_confidence: body.confidence,
        p_captured_at: body.captured_at,
        p_track_id: body.track_id,
      }),
      attach: (deviceId, eventId, path) =>
        rpc('device_lpr_attach_snapshot', {
          p_device_id: deviceId,
          p_event_id: eventId,
          p_path: path,
        }),
      upload: async (path, bytes) => {
        const response = await fetch(
          `${url}/storage/v1/object/evidence/${path}`,
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${key}`,
              apikey: key,
              'Content-Type': 'image/jpeg',
              'x-upsert': 'false',
            },
            body: bytes,
          },
        )
        return { status: response.status }
      },
      remove: async (path) => {
        await fetch(`${url}/storage/v1/object/evidence/${path}`, {
          method: 'DELETE',
          headers: {
            Authorization: `Bearer ${key}`,
            apikey: key,
          },
        })
      },
    },
    barrier: {
      config: (deviceId) => rpc('device_barrier_config', {
        p_device_id: deviceId,
      }),
      next: (deviceId) => rpc('device_barrier_next', { p_device_id: deviceId }),
      ack: (deviceId, commandId, result, detail) =>
        rpc('device_barrier_ack', {
          p_device_id: deviceId,
          p_command_id: commandId,
          p_result: result,
          p_detail: detail,
        }),
      event: (deviceId, clientRef, event, at, detail) =>
        rpc('device_barrier_event', {
          p_device_id: deviceId,
          p_client_ref: clientRef,
          p_event: event,
          p_at: at,
          p_detail: detail,
        }),
      firmware: (deviceId, current) =>
        rpc('device_firmware_manifest', {
          p_device_id: deviceId,
          p_current: current,
        }),
      image: async (version) => {
        const query = 'device_firmware?kind=eq.barrier' +
          `&version=eq.${encodeURIComponent(version)}` +
          '&released=eq.true&select=storage_path&limit=1'
        const response = await fetch(`${url}/rest/v1/${query}`, {
          headers: { apikey: key, Authorization: `Bearer ${key}` },
        })
        if (!response.ok) return null
        const rows = await response.json() as Array<{ storage_path?: string }>
        const path = rows[0]?.storage_path
        if (!path) return null
        const object = await fetch(
          `${url}/storage/v1/object/firmware/${path}`,
          { headers: { apikey: key, Authorization: `Bearer ${key}` } },
        )
        if (!object.ok) return null
        return new Uint8Array(await object.arrayBuffer())
      },
      signer: () => {
        signerPromise ??= createSigner(Deno.env.toObject())
        return signerPromise
      },
      sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
    },
    bays: {
      config: (deviceId) => rpc('device_bay_config', { p_device_id: deviceId }),
      report: (deviceId, channels, full) =>
        rpc('device_bay_report', {
          p_device_id: deviceId,
          p_channels: channels,
          p_full: full,
        }),
      firmware: (deviceId, current) =>
        rpc('device_firmware_manifest', {
          p_device_id: deviceId,
          p_current: current,
        }),
      image: async (version) => {
        const query = 'device_firmware?kind=eq.sensor_hub' +
          `&version=eq.${encodeURIComponent(version)}` +
          '&released=eq.true&select=storage_path&limit=1'
        const response = await fetch(`${url}/rest/v1/${query}`, {
          headers: { apikey: key, Authorization: `Bearer ${key}` },
        })
        if (!response.ok) return null
        const rows = await response.json() as Array<{ storage_path?: string }>
        const path = rows[0]?.storage_path
        if (!path) return null
        const object = await fetch(
          `${url}/storage/v1/object/firmware/${path}`,
          { headers: { apikey: key, Authorization: `Bearer ${key}` } },
        )
        if (!object.ok) return null
        return new Uint8Array(await object.arrayBuffer())
      },
    },
  }
}

if (import.meta.main) {
  Deno.serve(createHandler(realDeps()))
}
