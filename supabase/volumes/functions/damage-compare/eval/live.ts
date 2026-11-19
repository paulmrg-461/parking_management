// Live evaluation of the damage comparison against the real vision model.
//
// Manual only: it spends tokens and needs DEEPSEEK_API_KEY. It reads labelled
// photo pairs from $DAMAGE_FIXTURES_DIR (default
// damage-compare/fixtures/pairs, no images committed) — each pair directory
// has entry/*.jpg, exit/*.jpg and labels.json in the design's shape — runs
// the same prompt, vision call and normaliser as production, then scores the
// verdicts with the design's thresholds.
//
//   DEEPSEEK_API_KEY=... deno task eval:damage
//
// Never wired into CI.

import { join } from 'jsr:@std/path@^1'
import { loadConfig } from '../../_shared/ai/config.ts'
import { evalRefusal } from '../../_shared/ai/eval_guard.ts'
import { createVision, normalise } from '../index.ts'
import { scorePair, scoreSuite, type PairActual, type PairLabels } from './scoring.ts'

const env = Deno.env.toObject()
const refusal = evalRefusal(env, 'eval:damage')
if (refusal !== null) {
  console.error(refusal)
  Deno.exit(1)
}

const cfg = loadConfig(env)
const vision = createVision(env)
const minCovered = Number(env.AI_DAMAGE_MIN_COVERED_ZONES ?? '3') || 3
const dir = env.DAMAGE_FIXTURES_DIR ??
  join(import.meta.dirname!, '..', 'fixtures', 'pairs')

const IMAGE = /\.(jpe?g|png|webp)$/i
const MIME: Record<string, string> = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
}

function photos(path: string): Array<{ name: string; dataUrl: string }> {
  let names: string[] = []
  try {
    names = [...Deno.readDirSync(path)]
      .filter((entry) => entry.isFile && IMAGE.test(entry.name))
      .map((entry) => entry.name)
      .sort()
  } catch (_) {
    return []
  }
  return names.map((name) => {
    const bytes = Deno.readFileSync(join(path, name))
    const base64 = btoa(String.fromCharCode(...bytes))
    const ext = name.split('.').pop()!.toLowerCase()
    return { name, dataUrl: `data:${MIME[ext] ?? 'image/jpeg'};base64,${base64}` }
  })
}

type Photo = { dataUrl: string }

type Pair = {
  id: string
  labels: PairLabels
  entry: number[]
  exit: number[]
  entryPhotos: Photo[]
  exitPhotos: Photo[]
}

const pairs: Pair[] = []
let entries: Deno.DirEntry[] = []
try {
  entries = [...Deno.readDirSync(dir)]
} catch (_) {
  console.error(`no photo pairs under ${dir} (see fixtures/pairs/README.md)`)
  Deno.exit(1)
}
for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
  if (!entry.isDirectory) continue
  const path = join(dir, entry.name)
  const labels = JSON.parse(Deno.readTextFileSync(join(path, 'labels.json'))) as PairLabels
  const entryPhotos = photos(join(path, 'entry'))
  const exitPhotos = photos(join(path, 'exit'))
  if (entryPhotos.length === 0 || exitPhotos.length === 0) {
    console.error(`${entry.name}: needs entry/ and exit/ photos`)
    Deno.exit(1)
  }
  pairs.push({
    id: entry.name,
    labels,
    entry: entryPhotos.map((_, index) => index + 1),
    exit: exitPhotos.map((_, index) => index + 1001),
    entryPhotos,
    exitPhotos,
  })
}

if (pairs.length === 0) {
  console.error(`no photo pairs under ${dir} (see fixtures/pairs/README.md)`)
  Deno.exit(1)
}

const results: Array<{ id: string; labels: PairLabels; actual: PairActual }> = []
let tokens = 0
for (const pair of pairs) {
  const images = [
    ...pair.entryPhotos.map((photo, index) => ({
      label: `E${index + 1}`,
      dataUrl: photo.dataUrl,
    })),
    ...pair.exitPhotos.map((photo, index) => ({
      label: `X${index + 1}`,
      dataUrl: photo.dataUrl,
    })),
  ]
  const prompt = `Compare the entry and exit photos of the same vehicle.\n` +
    `Entry ids: ${JSON.stringify(pair.entry)}\n` +
    `Exit ids: ${JSON.stringify(pair.exit)}`
  let actual: PairActual
  try {
    const answer = await vision(prompt, images, cfg)
    tokens += (answer.usage.input ?? 0) + (answer.usage.output ?? 0)
    const parsed = JSON.parse(answer.content) as Record<string, unknown>
    const normalised = normalise(parsed, pair.entry, pair.exit, minCovered)
    actual = {
      overall: normalised.overall,
      findings: normalised.findings.map((finding) => ({
        zone: String(finding.zone),
        classification: String(finding.classification),
      })),
    }
  } catch (error) {
    console.error(`FAIL ${pair.id}: ${error instanceof Error ? error.message : error}`)
    Deno.exit(1)
  }
  results.push({ id: pair.id, labels: pair.labels, actual })
  const score = scorePair(pair.labels, actual)
  console.log(
    `${score.ok ? 'ok  ' : 'FAIL'} ${pair.id} [${pair.labels.category}] ` +
      `${pair.labels.overall} -> ${actual.overall}` +
      `${actual.findings.length > 0 ? ` (${actual.findings.length} findings)` : ''}`,
  )
  for (const problem of score.problems) console.log(`       ${problem}`)
}

const suite = scoreSuite(results)
console.log(
  `\n${suite.passed}/${suite.total} pairs, ` +
    `${suite.falsePositives} false positive(s) on A/D, ` +
    `${suite.bCorrect}/${suite.bTotal} B pairs with the right zone, ${tokens} tokens`,
)
for (const problem of suite.problems) console.log(`  ${problem}`)
if (!suite.ok) Deno.exit(1)
