import { assertEquals } from 'jsr:@std/assert@^1'
import { scorePair, scoreSuite, type PairActual, type PairLabels } from './scoring.ts'

const labels = (patch: Partial<PairLabels> = {}): PairLabels => ({
  category: 'A',
  same_vehicle: 'yes',
  overall: 'no_new_damage',
  findings: [],
  ...patch,
})

const none: PairActual = { overall: 'no_new_damage', findings: [] }
const unsure: PairActual = { overall: 'insufficient_evidence', findings: [] }
const detected: PairActual = {
  overall: 'possible_new_damage',
  findings: [{ zone: 'left', classification: 'new' }],
}

Deno.test('scoring has zero tolerance for an all-clear on E, G and H', () => {
  for (const category of ['E', 'G', 'H'] as const) {
    const score = scorePair(labels({ category }), none)
    assertEquals(score.ok, false)
    assertEquals(score.problems.length > 0, true)
  }
  assertEquals(scorePair(labels({ category: 'E' }), unsure).ok, true)
})

Deno.test('scoring excludes new damage from a pre-existing pair', () => {
  const score = scorePair(
    labels({ category: 'C', overall: 'no_new_damage' }),
    detected,
  )
  assertEquals(score.ok, false)
})

Deno.test('scoring requires the expected zone on B pairs', () => {
  const base = labels({
    category: 'B',
    overall: 'possible_new_damage',
    findings: [{ zone: 'left', classification: 'new' }],
  })
  assertEquals(scorePair(base, detected).ok, true)
  assertEquals(
    scorePair(base, {
      overall: 'possible_new_damage',
      findings: [{ zone: 'rear', classification: 'new' }],
    }).ok,
    false,
  )
  assertEquals(scorePair(base, none).ok, false)
})

Deno.test('scoring counts false positives in A and D', () => {
  const one = scorePair(labels(), detected)
  assertEquals(one.ok, true)
  assertEquals(one.falsePositive, true)
  // "Not enough evidence" is not a false positive.
  assertEquals(scorePair(labels(), unsure).falsePositive, false)
})

Deno.test('the suite allows one false positive and 4 of 5 B pairs', () => {
  const pair = (id: string, category: PairLabels['category'],
                actual: PairActual, findings: PairLabels['findings'] = []) => ({
    id,
    labels: labels({ category, findings }),
    actual,
  })
  const good = scoreSuite([
    pair('a1', 'A', none),
    pair('a2', 'A', none),
    pair('a3', 'A', detected), // the one allowed false positive
    pair('b1', 'B', detected, [{ zone: 'left', classification: 'new' }]),
    pair('b2', 'B', detected, [{ zone: 'left', classification: 'new' }]),
    pair('b3', 'B', detected, [{ zone: 'left', classification: 'new' }]),
    pair('b4', 'B', detected, [{ zone: 'left', classification: 'new' }]),
    pair('b5', 'B', none, [{ zone: 'left', classification: 'new' }]),
  ])
  assertEquals(good.ok, false) // b5 is an individual failure
  assertEquals(good.falsePositives, 1)
  assertEquals(good.bCorrect, 4)

  const twoFalsePositives = scoreSuite([
    pair('a1', 'A', detected),
    pair('a2', 'D', detected),
  ])
  assertEquals(twoFalsePositives.ok, false)
})
