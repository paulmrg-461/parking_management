import type { Unit } from '../figures/path.ts'

export type ArgSpec = {
  kind: 'date' | 'int'
  required?: boolean
  min?: number
  max?: number
  default?: number
}

export type ToolSpec = {
  name: string
  rpc: string
  description: string
  args: Record<string, ArgSpec>
  input_schema: Record<string, unknown>
  project(raw: unknown): unknown
  leafUnits: Record<string, Unit>
  maxRangeDays?: number
  enabled: boolean
}
