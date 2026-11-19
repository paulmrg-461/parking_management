export type Unit = 'money' | 'count' | 'percent' | 'hour'

export type PathResult = { leaf: string; values: number[] }

const BLOCKED = new Set(['__proto__', 'constructor', 'prototype'])
const KEY = /^[a-z_]+$/

export class PathError extends Error {}

type Selector =
  | { kind: 'index'; index: number }
  | { kind: 'field'; field: string; value: string }
  | { kind: 'star' }

type Segment = { key: string; selector?: Selector }

function parseSelector(raw: string): Selector {
  if (raw === '*') return { kind: 'star' }
  if (/^\d+$/.test(raw)) return { kind: 'index', index: Number(raw) }
  const eq = raw.indexOf('=')
  if (eq > 0) {
    const field = raw.slice(0, eq)
    if (!KEY.test(field)) throw new PathError('INVALID_PATH')
    return { kind: 'field', field, value: raw.slice(eq + 1) }
  }
  throw new PathError('INVALID_PATH')
}

function parse(path: string): Segment[] {
  if (path.length === 0 || path.length > 120) throw new PathError('INVALID_PATH')
  return path.split('.').map((raw) => {
    const match = /^([a-z_]+)(?:\[([^\]]{1,60})\])?$/.exec(raw)
    if (!match) throw new PathError('INVALID_PATH')
    const key = match[1]
    if (BLOCKED.has(key)) throw new PathError('INVALID_PATH')
    return {
      key,
      selector: match[2] === undefined ? undefined : parseSelector(match[2]),
    }
  })
}

function readKey(value: unknown, key: string): unknown {
  if (BLOCKED.has(key) || value === null || typeof value !== 'object') {
    throw new PathError('INVALID_PATH')
  }
  return (value as Record<string, unknown>)[key]
}

export function resolvePath(
  root: unknown,
  path: string,
  leafUnits: Record<string, Unit>,
): PathResult {
  const segments = parse(path)
  let current: unknown[] = [root]
  let leaf = ''

  for (let index = 0; index < segments.length; index++) {
    const segment = segments[index]
    const next: unknown[] = []
    for (const item of current) {
      const value = readKey(item, segment.key)
      if (!segment.selector) {
        next.push(value)
        continue
      }
      if (!Array.isArray(value)) throw new PathError('INVALID_PATH')
      if (segment.selector.kind === 'index') {
        const found = value[segment.selector.index]
        if (found === undefined) throw new PathError('MISSING_SELECTOR')
        next.push(found)
      } else if (segment.selector.kind === 'field') {
        const { field, value: expected } = segment.selector
        const found = value.find((entry) =>
          entry !== null && typeof entry === 'object' &&
          String((entry as Record<string, unknown>)[field]) === expected
        )
        if (found === undefined) throw new PathError('MISSING_SELECTOR')
        next.push(found)
      } else {
        // `[*]` may only be the list segment immediately before the leaf
        // (e.g. `by_day[*].amount`), never in the middle of a deeper path.
        if (index !== segments.length - 2) {
          throw new PathError('STAR_NOT_LAST')
        }
        next.push(...value)
      }
    }
    current = next
    leaf = segment.key
  }

  if (leafUnits[leaf] === undefined) throw new PathError('UNKNOWN_LEAF')
  const values = current.map((value) => {
    if (typeof value !== 'number' || !Number.isSafeInteger(value)) {
      throw new PathError('NON_INTEGER_LEAF')
    }
    return value
  })
  if (values.length === 0) throw new PathError('EMPTY_PATH')
  return { leaf, values }
}
