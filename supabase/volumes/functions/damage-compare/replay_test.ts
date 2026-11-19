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
  zone?: string
  entry_len?: number
  exit_len?: number
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
    same_vehicle?: string
    issues_count?: number
    covered_zones_count?: number
    summary_max?: number
    summary_excludes?: string
    summary_excludes_control?: boolean
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
      if (expected.zone !== undefined) assertEquals(finding['zone'], expected.zone)
      if (expected.description_excludes) {
        assertEquals(
          String(finding['description']).includes(expected.description_excludes),
          false,
        )
      }
      if (expected.entry_len !== undefined) {
        assertEquals((finding['entry_photo_ids'] as unknown[]).length, expected.entry_len)
      }
      if (expected.exit_len !== undefined) {
        assertEquals((finding['exit_photo_ids'] as unknown[]).length, expected.exit_len)
      }
    }
    const quality = result.quality as Record<string, unknown>
    if (fixture.expected.same_vehicle !== undefined) {
      assertEquals(quality['same_vehicle'], fixture.expected.same_vehicle)
    }
    if (fixture.expected.issues_count !== undefined) {
      assertEquals((quality['issues'] as unknown[]).length, fixture.expected.issues_count)
    }
    if (fixture.expected.covered_zones_count !== undefined) {
      assertEquals(
        (quality['covered_zones'] as unknown[]).length,
        fixture.expected.covered_zones_count,
      )
    }
    if (fixture.expected.summary_max !== undefined) {
      assertEquals(String(result.summary).length <= fixture.expected.summary_max, true)
    }
    if (fixture.expected.summary_excludes) {
      assertEquals(
        String(result.summary).includes(fixture.expected.summary_excludes),
        false,
      )
    }
    if (fixture.expected.summary_excludes_control) {
      assertEquals(/[\u0000-\u001f\u007f]/.test(String(result.summary)), false)
    }
  })
}
