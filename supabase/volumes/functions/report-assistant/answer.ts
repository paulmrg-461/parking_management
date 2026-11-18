import { computeOp, type FigureOp } from './figures/ops.ts'
import { resolvePath, type Unit } from './figures/path.ts'
import { sanitizeString } from './privacy.ts'
import type { ToolSpec } from './tools/types.ts'

export type IssuedResult = {
  callId: string
  rpc: string
  args: Record<string, string | number>
  projected: unknown
  tool: ToolSpec
  error?: string
}

export type ResolvedFigure = {
  id: string
  label: string
  unit: Unit
  op: FigureOp
  value: number | null
  note: string | null
  sources: Array<{
    call_id: string
    rpc: string
    args: Record<string, string | number>
    path: string
    raw: number
  }>
}

export type ResolvedAnswer = {
  status: 'answered' | 'needs_clarification' | 'out_of_scope' | 'no_data'
  headline: string
  explanation: string
  period_start: string | null
  period_end: string | null
  figures: ResolvedFigure[]
  caveats: string[]
}

export type CheckResult =
  | { ok: true; answer: ResolvedAnswer }
  | { ok: false; problems: string[] }

const STATUSES = new Set([
  'answered', 'needs_clarification', 'out_of_scope', 'no_data',
])
const OPS = new Set([
  'value', 'sum', 'difference', 'percent_change', 'share_percent',
])
const UNITS = new Set(['money', 'count', 'percent', 'hour'])
const PLACEHOLDER = /\{f(\d+)\}/g
const FIGURE_ID = /^f\d+$/

function digitsRule(text: string): boolean {
  const stripped = text.replace(PLACEHOLDER, '').replace(/20\d\d/g, '')
  return !/\d/.test(stripped)
}

function asText(value: unknown, max: number): string {
  return String(value ?? '').trim().slice(0, max)
}

export function validateAnswer(
  input: unknown,
  issued: Map<string, IssuedResult>,
): CheckResult {
  const raw = (input ?? {}) as Record<string, unknown>
  const problems: string[] = []
  const status = String(raw.status ?? '')
  if (!STATUSES.has(status)) problems.push('BAD_STATUS')

  const headline = asText(raw.headline, 200)
  const explanation = asText(raw.explanation, 600)
  if (!digitsRule(headline) || !digitsRule(explanation)) {
    problems.push('DIGITS_IN_PROSE')
  }
  const caveats = Array.isArray(raw.caveats)
    ? raw.caveats.slice(0, 3).map((item) => sanitizeString(item).slice(0, 200))
    : []

  const figuresRaw = Array.isArray(raw.figures) ? raw.figures : []
  if (status !== 'answered' && figuresRaw.length > 0) {
    problems.push('FIGURES_NOT_ALLOWED')
  }
  if (figuresRaw.length > 8) problems.push('TOO_MANY_FIGURES')

  const used = new Set<string>()
  for (const match of `${headline}\n${explanation}`.matchAll(PLACEHOLDER)) {
    used.add(`f${match[1]}`)
  }

  const figures: ResolvedFigure[] = []
  const ids = new Set<string>()
  for (const item of figuresRaw) {
    const figure = (item ?? {}) as Record<string, unknown>
    const id = String(figure.id ?? '')
    if (!FIGURE_ID.test(id) || ids.has(id)) {
      problems.push('BAD_FIGURE_ID')
      continue
    }
    ids.add(id)
    const op = String(figure.op ?? '') as FigureOp
    const unit = String(figure.unit ?? '') as Unit
    if (!OPS.has(op) || !UNITS.has(unit)) {
      problems.push('BAD_FIGURE_TYPE')
      continue
    }
    const operands = Array.isArray(figure.operands) ? figure.operands : []
    if (operands.length === 0
      || (op !== 'sum' && operands.length > 6)
      || (op === 'sum' && operands.length > 400)) {
      problems.push('BAD_OPERANDS')
      continue
    }

    const values: number[] = []
    const sources: ResolvedFigure['sources'] = []
    let leafUnit: Unit | null = null
    let failed = false
    for (const operand of operands) {
      const entry = (operand ?? {}) as Record<string, unknown>
      const callId = String(entry.call_id ?? '')
      const path = String(entry.path ?? '')
      const record = issued.get(callId)
      if (!record || record.error) {
        problems.push('UNKNOWN_CALL_ID')
        failed = true
        break
      }
      if (leafUnit !== null && unit !== leafUnit) {
        problems.push('MIXED_UNITS')
        failed = true
        break
      }
      try {
        const resolved = resolvePath(record.projected, path, record.tool.leafUnits)
        const unitOfLeaf = record.tool.leafUnits[resolved.leaf]
        if (leafUnit === null) {
          leafUnit = unitOfLeaf
        } else if (leafUnit !== unitOfLeaf) {
          problems.push('MIXED_UNITS')
          failed = true
          break
        }
        if (op !== 'sum' && resolved.values.length !== 1) {
          problems.push('BAD_OPERANDS')
          failed = true
          break
        }
        for (const value of resolved.values) {
          values.push(value)
          sources.push({
            call_id: callId,
            rpc: record.rpc,
            args: record.args,
            path,
            raw: value,
          })
        }
      } catch (error) {
        problems.push(error instanceof Error ? error.message : 'BAD_PATH')
        failed = true
        break
      }
    }
    if (failed) continue;

    let computed
    try {
      computed = computeOp(op, values, leafUnit ?? unit)
    } catch (error) {
      problems.push(error instanceof Error ? error.message : 'BAD_OPERATION')
      continue
    }
    if (computed.unit !== unit) {
      problems.push('UNIT_MISMATCH')
      continue
    }
    if (used.has(id)) {
      figures.push({
        id,
        label: sanitizeString(figure.label).slice(0, 80),
        unit,
        op,
        value: computed.value,
        note: computed.note ?? null,
        sources,
      })
    }
  }

  for (const id of used) {
    if (!figures.some((figure) => figure.id === id)) {
      problems.push('PLACEHOLDER_WITHOUT_FIGURE')
    }
  }
  if (problems.length > 0) return { ok: false, problems }

  const periodStart = String(raw.period_start ?? '').trim()
  const periodEnd = String(raw.period_end ?? '').trim()
  return {
    ok: true,
    answer: {
      status: status as ResolvedAnswer['status'],
      headline,
      explanation,
      period_start: periodStart === '' ? null : periodStart,
      period_end: periodEnd === '' ? null : periodEnd,
      figures,
      caveats,
    },
  }
}
