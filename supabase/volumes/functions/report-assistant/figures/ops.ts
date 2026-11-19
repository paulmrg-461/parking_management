import type { Unit } from './path.ts'

export type FigureOp =
  | 'value'
  | 'sum'
  | 'difference'
  | 'percent_change'
  | 'share_percent'

export type OpResult = { value: number | null; unit: Unit; note?: string }

export class OpError extends Error {}

function toBig(value: number): bigint {
  if (!Number.isSafeInteger(value)) throw new OpError('UNSAFE_INTEGER')
  return BigInt(value)
}

function safe(value: bigint): number {
  const number = Number(value)
  if (!Number.isSafeInteger(number)) throw new OpError('UNSAFE_INTEGER')
  return number
}

// Half away from zero, on BigInt (no float drift).
export function divRound(numerator: bigint, denominator: bigint): bigint {
  if (denominator === 0n) throw new OpError('ZERO_DIVISOR')
  const negative = (numerator < 0n) !== (denominator < 0n)
  const n = numerator < 0n ? -numerator : numerator
  const d = denominator < 0n ? -denominator : denominator
  const quotient = n / d
  const remainder = n % d
  const rounded = remainder * 2n >= d ? quotient + 1n : quotient
  return negative ? -rounded : rounded
}

export function computeOp(
  op: FigureOp,
  values: number[],
  unit: Unit,
): OpResult {
  if (op === 'percent_change' || op === 'share_percent') {
    if (values.length !== 2) throw new OpError('BAD_OPERANDS')
    const a = toBig(values[0])
    const b = toBig(values[1])
    const base = op === 'percent_change' ? a : b
    if (base === 0n) {
      return { value: null, unit: 'percent', note: 'undefined_base' }
    }
    const numerator = op === 'percent_change'
      ? (b - a) * 10000n
      : a * 10000n
    return { value: safe(divRound(numerator, base)), unit: 'percent' }
  }

  if (op === 'value') {
    if (values.length !== 1) throw new OpError('BAD_OPERANDS')
    return { value: values[0], unit }
  }
  if (op === 'sum') {
    return {
      value: safe(values.reduce((total, value) => total + toBig(value), 0n)),
      unit,
    }
  }
  if (op === 'difference') {
    if (values.length !== 2) throw new OpError('BAD_OPERANDS')
    return { value: safe(toBig(values[0]) - toBig(values[1])), unit }
  }
  throw new OpError('BAD_OPERANDS')
}
