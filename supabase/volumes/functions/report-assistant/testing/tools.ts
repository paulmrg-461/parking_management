import type { ToolSpec } from '../tools/types.ts'

export const revenueTool = {
  name: 'get_revenue_report',
  rpc: 'report_revenue',
  description: '',
  args: {},
  input_schema: {},
  project: (raw) => raw,
  leafUnits: { total: 'money', amount: 'money' },
  enabled: true,
} satisfies ToolSpec
