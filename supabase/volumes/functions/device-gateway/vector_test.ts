// Shared test vector for the TypeScript signer and the C++ firmware test.
//
// Regenerate with:
//   UPDATE_VECTORS=1 deno test --allow-env --allow-read device-gateway/vector_test.ts
// and commit the file. CI compares it, so a change in the canonical message
// or the signing code fails here before it reaches a device.

import { assertEquals } from 'jsr:@std/assert@^1'
import { join } from 'jsr:@std/path@^1'
import { canonicalMessage, createSigner } from './signing.ts'
import { TEST_PRIVATE_KEY, TEST_PUBLIC_KEY, testCommand } from './signing_fixtures.ts'

const path = join(
  import.meta.dirname!,
  '..', '..', '..', '..',
  'edge', 'barrier', 'test', 'vectors', 'command_v1.json',
)

Deno.test('shared command vector', async () => {
  const signer = await createSigner({
    BARRIER_COMMAND_SIGNING_KEY: TEST_PRIVATE_KEY,
  })
  const signature = await signer.sign(testCommand)
  const expected = {
    version: 'parking-barrier-v1',
    public_key_spki_b64: TEST_PUBLIC_KEY,
    command: testCommand,
    message: canonicalMessage(testCommand),
    signature_b64: signature,
  }
  if (Deno.env.get('UPDATE_VECTORS') === '1') {
    await Deno.mkdir(join(path, '..'), { recursive: true })
    await Deno.writeTextFile(path, `${JSON.stringify(expected, null, 2)}\n`)
    return
  }
  const stored = JSON.parse(await Deno.readTextFile(path))
  assertEquals(stored, expected)
})
