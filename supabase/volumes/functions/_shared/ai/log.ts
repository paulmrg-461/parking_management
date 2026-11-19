// One JSON line per request. Never question, answer, tool result or PII.
const ALLOWED = new Set([
  'fn', 'feature', 'request_id', 'lot', 'status', 'ms', 'in_tok', 'out_tok',
  'cache_read', 'tool_calls', 'iterations', 'error', 'model',
])

export function logLine(fields: Record<string, unknown>): void {
  const safe: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(fields)) {
    if (ALLOWED.has(key)) {
      safe[key] = value
    }
  }
  console.log(JSON.stringify(safe))
}
