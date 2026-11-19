// Scoring for the manual damage live eval (design D12). Pure: the pair
// results come from normalise(), so the thresholds are tested without any
// photo or network call.

export type PairCategory = 'A' | 'B' | 'C' | 'D' | 'E' | 'F' | 'G' | 'H'

export type PairLabels = {
  category: PairCategory
  same_vehicle: string
  overall: 'no_new_damage' | 'possible_new_damage' | 'insufficient_evidence'
  findings: Array<{ zone: string; classification: string }>
  must_not_say_none?: boolean
}

export type PairActual = {
  overall: string
  findings: Array<{ zone: string; classification: string }>
}

export type PairScore = {
  ok: boolean
  falsePositive: boolean
  problems: string[]
}

const ZERO_TOLERANCE_NONE: PairCategory[] = ['E', 'G', 'H']

export function scorePair(labels: PairLabels, actual: PairActual): PairScore {
  const problems: string[] = []
  const newFindings = actual.findings.filter(
    (finding) => finding.classification === 'new',
  )
  let falsePositive = false

  if (labels.must_not_say_none === true && actual.overall === 'no_new_damage') {
    problems.push('said no_new_damage but the pair must not')
  }

  if (ZERO_TOLERANCE_NONE.includes(labels.category)) {
    if (actual.overall !== 'insufficient_evidence') {
      problems.push(
        `category ${labels.category} must be insufficient_evidence, got ${actual.overall}`,
      )
    }
  } else if (labels.category === 'C') {
    if (newFindings.length > 0) {
      problems.push('a pre-existing pair reported new damage')
    }
  } else if (labels.category === 'B') {
    if (actual.overall !== 'possible_new_damage') {
      problems.push(`category B missed the damage (${actual.overall})`)
    }
    const expectedZones = labels.findings
      .filter((finding) => finding.classification === 'new')
      .map((finding) => finding.zone)
    if (!newFindings.some((finding) => expectedZones.includes(finding.zone))) {
      problems.push(`no new finding in the expected zones (${expectedZones.join(',')})`)
    }
  } else if (labels.overall === 'no_new_damage') {
    // A/D: an all-clear or "not enough evidence" is fine; a positive is a
    // false positive and counts against the suite budget.
    if (actual.overall === 'possible_new_damage') {
      falsePositive = true
    }
  } else if (actual.overall !== labels.overall) {
    problems.push(`expected ${labels.overall}, got ${actual.overall}`)
  }

  return { ok: problems.length === 0, falsePositive, problems }
}

export type SuiteScore = {
  ok: boolean
  passed: number
  total: number
  falsePositives: number
  bCorrect: number
  bTotal: number
  problems: string[]
}

// Design D12: no pair may fail its own rule, at most one false positive
// across A+D, and at least 80% of the B pairs must flag the right zone.
export function scoreSuite(
  results: Array<{ id: string; labels: PairLabels; actual: PairActual }>,
): SuiteScore {
  const problems: string[] = []
  let passed = 0
  let falsePositives = 0
  let bCorrect = 0
  let bTotal = 0
  for (const result of results) {
    const score = scorePair(result.labels, result.actual)
    if (score.ok) passed += 1
    if (score.falsePositive) falsePositives += 1
    if (result.labels.category === 'B') {
      bTotal += 1
      if (score.ok) bCorrect += 1
    }
    for (const problem of score.problems) {
      problems.push(`${result.id}: ${problem}`)
    }
  }
  if (falsePositives > 1) {
    problems.push(
      `${falsePositives} false positives on A/D (budget is 1)`,
    )
  }
  const bBar = Math.ceil(bTotal * 0.8)
  if (bTotal > 0 && bCorrect < bBar) {
    problems.push(`only ${bCorrect}/${bTotal} B pairs found the right zone (bar ${bBar})`)
  }
  return {
    ok: problems.length === 0 && passed === results.length,
    passed,
    total: results.length,
    falsePositives,
    bCorrect,
    bTotal,
    problems,
  }
}
