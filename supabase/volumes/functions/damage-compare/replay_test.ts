// Replay harness for the damage comparison: feeds recorded model JSON through
// the real normaliser and asserts the verdict/downgrades/sanitisation. No
// network and no images, so it runs in the CI edge-functions job.

import { assertEquals } from 'jsr:@std/assert@^1'
import { join } from 'jsr:@std/path'
import { normalise } from './index.ts'

type Finding = {
  classification: string
  downgraded_from?: string | null
  description_excludes?: string
}

type Fixture = {
  case: string
  entry_ids: number[]
  exit_ids: number[]
  model_answer: Record<string, unknown>
  expected: {
    overall: string
    count: number
    findings?: Finding[]
  }
}

const dir = join(import.meta.dirname!, 'fixtures', 'replay')

for (const file of Deno.readDirSync(dir)) {
  if (!file.name.endsWith('.json')) continue
  const fixture = JSON.parse(
    Deno.readTextFileSync(join(dir, file.name)),
  ) as Fixture

  Deno.test(`damage replay ${file.name}: ${fixture.case}`, () => {
    const result = normalise(fixture.model_answer, fixture.entry_ids, fixture.exit_ids)
    assertEquals(result.overall, fixture.expected.overall)
    assertEquals(result.findings.length, fixture.expected.count)
    const findings = result.findings as Array<Record<string, unknown>>
    for (const [index, expected] of (fixture.expected.findings ?? []).entries()) {
      const finding = findings[index]
      assertEquals(finding['classification'], expected.classification)
      if (expected.downgraded_from !== undefined) {
        assertEquals(finding['downgraded_from'], expected.downgraded_from)
      }
      if (expected.description_excludes) {
        assertEquals(
          String(finding['description']).includes(expected.description_excludes),
          false,
        )
      }
    }
  })
}
