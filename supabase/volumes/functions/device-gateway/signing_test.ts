import { assertEquals, assertRejects } from 'jsr:@std/assert@^1'
import {
  base64ToArrayBuffer,
  canonicalMessage,
  createSigner,
  SigningUnavailableError,
} from './signing.ts'
import {
  TEST_PRIVATE_KEY,
  TEST_PUBLIC_KEY,
  testCommand,
} from './signing_fixtures.ts'

const env = { BARRIER_COMMAND_SIGNING_KEY: TEST_PRIVATE_KEY }

Deno.test('canonical message matches the spec exactly', () => {
  assertEquals(
    canonicalMessage(testCommand),
    'parking-barrier-v1|6f1c1d8e-0b34-4d44-8a3e-6f5c1c1d9a10|7|open|1731247401|1731247431|9f2c4a7e1b3d5f60718293a4b5c6d7e8|1000|20',
  )
})

Deno.test('signature verifies with the public key', async () => {
  const signer = await createSigner(env)
  const signature = await signer.sign(testCommand)
  const key = await crypto.subtle.importKey(
    'spki',
    base64ToArrayBuffer(TEST_PUBLIC_KEY),
    { name: 'Ed25519' },
    false,
    ['verify'],
  )
  const valid = await crypto.subtle.verify(
    'Ed25519',
    key,
    base64ToArrayBuffer(signature),
    new TextEncoder().encode(canonicalMessage(testCommand)),
  )
  assertEquals(valid, true)
  assertEquals(base64ToArrayBuffer(signature).byteLength, 64)
})

Deno.test('the signed message includes hold_ms and max_open_s', async () => {
  const signer = await createSigner(env)
  const longer = await signer.sign({ ...testCommand, hold_ms: 5000 })
  const wider = await signer.sign({ ...testCommand, max_open_s: 60 })
  const base = await signer.sign(testCommand)
  assertEquals(longer === base, false)
  assertEquals(wider === base, false)
  assertEquals(
    canonicalMessage({ ...testCommand, hold_ms: 5000 }).includes('|5000|20'),
    true,
  )
})

Deno.test('a missing or malformed key fails closed', async () => {
  await assertRejects(
    () => createSigner({}),
    SigningUnavailableError,
  )
  await assertRejects(
    () => createSigner({ BARRIER_COMMAND_SIGNING_KEY: 'not-a-key' }),
    SigningUnavailableError,
  )
})

Deno.test('malformed commands are refused before signing', async () => {
  const signer = await createSigner(env)
  await assertRejects(
    () => signer.sign({ ...testCommand, id: 'not-a-uuid' }),
    Error,
    'InvalidCommandError',
  )
  await assertRejects(
    () => signer.sign({ ...testCommand, nonce: 'zz' }),
    Error,
    'InvalidCommandError',
  )
  await assertRejects(
    () => signer.sign({ ...testCommand, expires_at: testCommand.issued_at }),
    Error,
    'InvalidCommandError',
  )
})

Deno.test('the private key is never logged', async () => {
  const captured: string[] = []
  const originals = {
    log: console.log,
    info: console.info,
    warn: console.warn,
    error: console.error,
    debug: console.debug,
  }
  const spy = (...args: unknown[]) => {
    captured.push(args.map((arg) => String(arg)).join(' '))
  }
  console.log = spy
  console.info = spy
  console.warn = spy
  console.error = spy
  console.debug = spy
  try {
    const signer = await createSigner(env)
    await signer.sign(testCommand)
  } finally {
    console.log = originals.log
    console.info = originals.info
    console.warn = originals.warn
    console.error = originals.error
    console.debug = originals.debug
  }
  for (const line of captured) {
    assertEquals(line.includes(TEST_PRIVATE_KEY), false)
    assertEquals(line.includes(TEST_PRIVATE_KEY.slice(0, 24)), false)
  }
})
