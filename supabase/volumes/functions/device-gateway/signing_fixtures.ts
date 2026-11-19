// Shared, test-only Ed25519 material. The private key exists only in the
// tests; the public key and the vector are also read by the C++ firmware test.

import type { SignableCommand } from './signing.ts'

export const TEST_PRIVATE_KEY =
  'MC4CAQAwBQYDK2VwBCIEIJjrrVt07bQpmt/rPlt9XipIlDopDfrMT+nsmn22AXkK'
export const TEST_PUBLIC_KEY =
  'MCowBQYDK2VwAyEAbk49EEZ4exPyZAQ3uvD+S5CQWw52X9NbcTY+i6ZQWBs='

export const testCommand: SignableCommand = {
  id: '6f1c1d8e-0b34-4d44-8a3e-6f5c1c1d9a10',
  device_id: 7,
  issued_at: 1731247401,
  expires_at: 1731247431,
  nonce: '9f2c4a7e1b3d5f60718293a4b5c6d7e8',
  hold_ms: 1000,
  max_open_s: 20,
}
