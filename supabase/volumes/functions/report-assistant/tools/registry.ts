import type { Unit } from '../figures/path.ts'
import type { ArgSpec, ToolSpec } from './types.ts'

const DATE_ARGS: Record<string, ArgSpec> = {
  p_start_date: { kind: 'date', required: true },
  p_end_date: { kind: 'date', required: true },
}

const DATE_SCHEMA = {
  type: 'object',
  properties: {
    start_date: { type: 'string', description: 'First day, YYYY-MM-DD' },
    end_date: { type: 'string', description: 'Last day, YYYY-MM-DD' },
  },
  required: ['start_date', 'end_date'],
  additionalProperties: false,
}

const EMPTY_SCHEMA = {
  type: 'object',
  properties: {},
  additionalProperties: false,
}

function pick(raw: unknown, keys: string[]): Record<string, unknown> {
  const source = (raw ?? {}) as Record<string, unknown>
  const result: Record<string, unknown> = {}
  for (const key of keys) {
    if (source[key] !== undefined) result[key] = source[key]
  }
  return result
}

function pickList(raw: unknown, keys: string[]): unknown[] {
  return Array.isArray(raw)
    ? raw.map((item) => pick(item, keys))
    : []
}

const MONEY: Unit = 'money'
const COUNT: Unit = 'count'

const revenue: ToolSpec = {
  name: 'get_revenue_report',
  rpc: 'report_revenue',
  description:
    'Revenue of the active lot for an inclusive date range in the lot timezone: total, pass revenue, discounts, and amounts by day, by vehicle category and by payment method. Call it for money questions or to compare two periods (once per period). Maximum range 400 days.',
  args: DATE_ARGS,
  input_schema: DATE_SCHEMA,
  maxRangeDays: 400,
  enabled: true,
  project: (raw) => {
    const source = (raw ?? {}) as Record<string, unknown>
    return {
      ...pick(source, [
        'total', 'pass_revenue', 'total_discounts', 'discounted_sessions',
        'start_date', 'end_date',
      ]),
      by_day: pickList(source.by_day, ['date', 'amount']),
      by_category: pickList(source.by_category, [
        'category_id', 'category_name', 'amount',
      ]),
      by_payment: pickList(source.by_payment, ['payment_method', 'amount']),
      pass_by_payment: pickList(source.pass_by_payment, [
        'payment_method', 'amount',
      ]),
    }
  },
  leafUnits: {
    total: MONEY,
    pass_revenue: MONEY,
    total_discounts: MONEY,
    discounted_sessions: COUNT,
    amount: MONEY,
  },
}

const hourlyTraffic: ToolSpec = {
  name: 'get_hourly_traffic',
  rpc: 'report_hourly_traffic',
  description:
    'Vehicle entries and exits per hour of the business day (0-23) summed over an inclusive date range. Call it for busiest/quietest hour or staffing questions.',
  args: DATE_ARGS,
  input_schema: DATE_SCHEMA,
  maxRangeDays: 400,
  enabled: true,
  project: (raw) => pick(raw, ['hours', 'timezone']),
  leafUnits: { hour: 'hour', entries: COUNT, exits: COUNT },
}

const reservations: ToolSpec = {
  name: 'get_reservations_report',
  rpc: 'report_reservations',
  description:
    'Reservation counts for an inclusive date range: total, public/app, used, used from public bookings, cancelled, expired, active and the waitlist counters.',
  args: DATE_ARGS,
  input_schema: DATE_SCHEMA,
  maxRangeDays: 400,
  enabled: true,
  project: (raw) => pick(raw, [
    'total', 'public', 'app', 'used', 'used_public', 'cancelled', 'expired',
    'active', 'waitlist_joined', 'waitlist_offered', 'waitlist_claimed',
    'waitlist_expired', 'waitlist_left', 'waitlist_cancelled',
    'waitlist_waiting',
  ]),
  leafUnits: {
    total: COUNT, public: COUNT, app: COUNT, used: COUNT,
    used_public: COUNT, cancelled: COUNT, expired: COUNT, active: COUNT,
    waitlist_joined: COUNT, waitlist_offered: COUNT,
    waitlist_claimed: COUNT, waitlist_expired: COUNT,
    waitlist_left: COUNT, waitlist_cancelled: COUNT, waitlist_waiting: COUNT,
  },
}

const whatsapp: ToolSpec = {
  name: 'get_whatsapp_report',
  rpc: 'report_whatsapp',
  description:
    'Customer WhatsApp delivery counters for an inclusive date range (sent, failed, pending and the daily series).',
  args: DATE_ARGS,
  input_schema: DATE_SCHEMA,
  maxRangeDays: 400,
  enabled: true,
  project: (raw) => pick(raw, ['sent', 'failed', 'pending', 'by_day']),
  leafUnits: { sent: COUNT, failed: COUNT, pending: COUNT, count: COUNT },
}

const occupancy: ToolSpec = {
  name: 'get_occupancy_now',
  rpc: 'report_occupancy',
  description:
    'Current occupancy: opens, holds and capacity, overall and per vehicle category. Call it for "how full is it now" questions.',
  args: {},
  input_schema: EMPTY_SCHEMA,
  enabled: true,
  project: (raw) => {
    const source = (raw ?? {}) as Record<string, unknown>
    return {
      ...pick(source, ['total_open', 'total_reserved', 'total_capacity']),
      by_category: pickList(source.by_category, [
        'category_id', 'category_name', 'count', 'capacity', 'reserved',
        'available', 'is_full',
      ]),
    }
  },
  leafUnits: {
    total_open: COUNT, total_reserved: COUNT, total_capacity: COUNT,
    count: COUNT, capacity: COUNT, reserved: COUNT, available: COUNT,
  },
}

const capacity: ToolSpec = {
  name: 'get_capacity_now',
  rpc: 'capacity_snapshot',
  description:
    'Current car/moto capacity, availability, out-of-service bays, active/expiring holds and keys.',
  args: {},
  input_schema: EMPTY_SCHEMA,
  enabled: true,
  project: (raw) => pick(raw, [
    'car_open', 'car_capacity', 'car_available', 'car_out_of_service',
    'car_target_capacity', 'moto_open', 'moto_capacity', 'moto_available',
    'moto_out_of_service', 'moto_target_capacity', 'reservations_active',
    'reservations_expiring', 'car_reserved', 'moto_reserved', 'keys_open',
    'key_capacity',
  ]),
  leafUnits: {
    car_open: COUNT, car_capacity: COUNT, car_available: COUNT,
    car_out_of_service: COUNT, car_target_capacity: COUNT,
    moto_open: COUNT, moto_capacity: COUNT, moto_available: COUNT,
    moto_out_of_service: COUNT, moto_target_capacity: COUNT,
    reservations_active: COUNT, reservations_expiring: COUNT,
    car_reserved: COUNT, moto_reserved: COUNT, keys_open: COUNT,
    key_capacity: COUNT,
  },
}

const today: ToolSpec = {
  name: 'get_today_summary',
  rpc: 'dashboard_today',
  description:
    'Today so far in the lot timezone: revenue, cash revenue, pass revenue, entries, exits and how many vehicles are inside now.',
  args: {},
  input_schema: EMPTY_SCHEMA,
  enabled: true,
  project: (raw) => pick(raw, [
    'revenue', 'cash_revenue', 'pass_revenue', 'entries', 'exits', 'open_now',
  ]),
  leafUnits: {
    revenue: MONEY, cash_revenue: MONEY, pass_revenue: MONEY,
    entries: COUNT, exits: COUNT, open_now: COUNT,
  },
}

const trend: ToolSpec = {
  name: 'get_daily_trend',
  rpc: 'dashboard_trend',
  description:
    'Daily revenue, entries and exits for the last N days (1..31, default 7).',
  args: { p_days: { kind: 'int', min: 1, max: 31, default: 7 } },
  input_schema: {
    type: 'object',
    properties: {
      days: { type: 'integer', description: '1 to 31, default 7' },
    },
    additionalProperties: false,
  },
  enabled: true,
  project: (raw) => {
    const source = (raw ?? {}) as Record<string, unknown>
    return {
      ...pick(source, ['start_date', 'end_date']),
      days: pickList(source.days, ['date', 'revenue', 'entries', 'exits']),
    }
  },
  leafUnits: { revenue: MONEY, entries: COUNT, exits: COUNT },
}

const SHIFT_MONEY = [
  'opening_float', 'counted_cash', 'expected_cash', 'difference', 'revenue',
  'cash_sales', 'card_sales', 'transfer_sales', 'pass_sales', 'exempt_sales',
  'discounts', 'pass_cash_sales', 'pass_payments', 'withdrawals', 'deposits',
]

const shifts: ToolSpec = {
  name: 'get_shift_summaries',
  rpc: 'list_shifts',
  description:
    'Shift closes with opening float, counted/expected cash, difference and sales by payment method. Call it for cash difference, closing or collection questions.',
  args: {
    p_limit: { kind: 'int', min: 1, max: 50, default: 20 },
    p_start_date: { kind: 'date' },
    p_end_date: { kind: 'date' },
  },
  input_schema: {
    type: 'object',
    properties: {
      limit: { type: 'integer', description: '1 to 50, default 20' },
      start_date: { type: 'string', description: 'Optional first day, YYYY-MM-DD' },
      end_date: { type: 'string', description: 'Optional last day, YYYY-MM-DD' },
    },
    additionalProperties: false,
  },
  maxRangeDays: 400,
  enabled: true,
  project: (raw) => ({
    // Wrapped so the path grammar (keys first) can address one shift.
    shifts: (Array.isArray(raw) ? raw : []).map((row) => pick(row, [
      'id', 'opened_at', 'closed_at', 'session_count', ...SHIFT_MONEY,
    ])),
  }),
  leafUnits: {
    ...Object.fromEntries(SHIFT_MONEY.map((key) => [key, MONEY])),
    session_count: COUNT,
  },
}

const disabled: ToolSpec[] = [
  ['report_revenue_all', 'report_revenue_all'],
  ['session_records', 'session_records'],
  ['vehicle_history', 'vehicle_history'],
  ['list_audit_log', 'list_audit_log'],
].map(([name, rpc]) => ({
  name,
  rpc,
  description: 'Disabled: cross-lot or personal data. Never offered.',
  args: {},
  input_schema: EMPTY_SCHEMA,
  enabled: false,
  project: () => null,
  leafUnits: {},
}))

export const TOOL_REGISTRY: ToolSpec[] = [
  revenue, hourlyTraffic, reservations, whatsapp, occupancy, capacity, today,
  trend, shifts, ...disabled,
]

export const ENABLED_TOOLS = TOOL_REGISTRY.filter((tool) => tool.enabled)

export function findTool(name: string): ToolSpec | undefined {
  return ENABLED_TOOLS.find((tool) => tool.name === name)
}

// ---------------------------------------------------------------------------
// Argument validation (the RPC never runs on invalid input).
// ---------------------------------------------------------------------------
const DATE = /^\d{4}-\d{2}-\d{2}$/

function realDate(value: string): boolean {
  if (!DATE.test(value)) return false
  const date = new Date(`${value}T00:00:00Z`)
  return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(value)
}

export type ArgResult =
  | { ok: true; args: Record<string, string | number> }
  | { ok: false; detail: string }

export function validateArgs(
  spec: ToolSpec,
  raw: unknown,
): ArgResult {
  const input = (raw ?? {}) as Record<string, unknown>
  const args: Record<string, string | number> = {}
  for (const [rpcName, rule] of Object.entries(spec.args)) {
    const key = rpcName.replace(/^p_/, '')
    let value = input[key]
    if (value === undefined || value === null || value === '') {
      if (rule.default !== undefined) {
        value = rule.default
      } else if (rule.required) {
        return { ok: false, detail: `missing ${key}` }
      } else {
        continue
      }
    }
    if (rule.kind === 'date') {
      const text = String(value)
      if (!realDate(text)) return { ok: false, detail: `invalid ${key}` }
      args[rpcName] = text
    } else {
      const number = Number(value)
      if (!Number.isInteger(number)
        || (rule.min !== undefined && number < rule.min)
        || (rule.max !== undefined && number > rule.max)) {
        return { ok: false, detail: `invalid ${key}` }
      }
      args[rpcName] = number
    }
  }
  const start = args.p_start_date
  const end = args.p_end_date
  if (typeof start === 'string' && typeof end === 'string') {
    if (end < start) return { ok: false, detail: 'end before start' }
    const days = (Date.parse(end) - Date.parse(start)) / 86_400_000 + 1
    if (days > (spec.maxRangeDays ?? 400)) {
      return { ok: false, detail: 'range too long' }
    }
  }
  return { ok: true, args }
}
