// Ed25519 command signing for the barrier gateway.
//
// The database stores the command facts; the private key lives only in the
// functions container (`BARRIER_COMMAND_SIGNING_KEY`, base64 PKCS#8). The
// device verifies the signature against a public key baked into the firmware,
// so neither the database nor a stolen device key can forge an "open".
//
// Canonical message (UTF-8, '|' separated, no trailing newline):
//   parking-barrier-v1|<uuid>|<device id>|open|<issued s>|<expires s>|<nonce>|<hold_ms>|<max_open_s>
//
// The timings are inside the signed bytes so a MITM cannot lengthen the
// opening. Never log the key material.

export const COMMAND_VERSION = 'parking-barrier-v1'

const NONCE = /^[0-9a-f]{32}$/
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export type SignableCommand = {
  id: string
  device_id: number
  issued_at: number
  expires_at: number
  nonce: string
  hold_ms: number
  max_open_s: number
}

export type BarrierSigner = {
  sign(command: SignableCommand): Promise<string>
  /** SPKI base64 of the matching public key, for operations and tests. */
  publicKey: string
}

export class SigningUnavailableError extends Error {
  constructor() {
    super('SigningUnavailableError')
  }
}

export function canonicalMessage(command: SignableCommand): string {
  if (!UUID.test(command.id)) {
    throw new Error('InvalidCommandError')
  }
  if (!NONCE.test(command.nonce)) {
    throw new Error('InvalidCommandError')
  }
  for (const value of [
    command.device_id,
    command.issued_at,
    command.expires_at,
    command.hold_ms,
    command.max_open_s,
  ]) {
    if (!Number.isInteger(value) || value < 0) {
      throw new Error('InvalidCommandError')
    }
  }
  if (command.expires_at <= command.issued_at) {
    throw new Error('InvalidCommandError')
  }
  return [
    COMMAND_VERSION,
    command.id,
    command.device_id,
    'open',
    command.issued_at,
    command.expires_at,
    command.nonce,
    command.hold_ms,
    command.max_open_s,
  ].join('|')
}

export async function createSigner(
  env: Record<string, string | undefined>,
): Promise<BarrierSigner> {
  const encoded = (env.BARRIER_COMMAND_SIGNING_KEY ?? '').trim()
  if (encoded === '') {
    throw new SigningUnavailableError()
  }
  let key: CryptoKey
  try {
    key = await crypto.subtle.importKey(
      'pkcs8',
      base64ToArrayBuffer(encoded),
      { name: 'Ed25519' },
      false,
      ['sign'],
    )
  } catch (_) {
    // A malformed key must fail closed like a missing one.
    throw new SigningUnavailableError()
  }
  const encoder = new TextEncoder()
  return {
    publicKey: '',
    async sign(command: SignableCommand): Promise<string> {
      const message = canonicalMessage(command)
      const signature = await crypto.subtle.sign(
        'Ed25519',
        key,
        encoder.encode(message),
      )
      return bytesToBase64(new Uint8Array(signature))
    },
  }
}

export function base64ToBytes(encoded: string): Uint8Array {
  const normalized = encoded.replace(/\s/g, '')
  const binary = atob(normalized)
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index)
  }
  return bytes
}

export function base64ToArrayBuffer(encoded: string): ArrayBuffer {
  const bytes = base64ToBytes(encoded)
  const copy = new Uint8Array(new ArrayBuffer(bytes.length))
  copy.set(bytes)
  return copy.buffer
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = ''
  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }
  return btoa(binary)
}
