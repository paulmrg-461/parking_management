const PLATE = /\b[A-Za-z]{3}[\s-]?\d{2,3}[A-Za-z]?\b/g
const LONG_DIGITS = /\+?\d[\d\s-]{6,}\d/g
const EMAIL = /[^\s@]+@[^\s@]+\.[^\s@]+/g

export function redact(text: string): { text: string; redacted: boolean } {
  let redacted = false
  const value = text
    .replace(EMAIL, () => {
      redacted = true
      return '[REDACTED]'
    })
    .replace(PLATE, () => {
      redacted = true
      return '[REDACTED]'
    })
    .replace(LONG_DIGITS, () => {
      redacted = true
      return '[REDACTED]'
    })
  return { text: value, redacted }
}

export function sanitizeString(value: unknown): string {
  return String(value ?? '')
    // eslint-disable-next-line no-control-regex
    .replace(/[\u0000-\u001f\u007f]/g, '')
    .replace(/[<>]/g, '')
    .trim()
    .slice(0, 60)
}

export function capBytes(value: unknown, limit = 60_000): string | null {
  const text = JSON.stringify(value)
  return text.length <= limit ? text : null
}

export function sanitizeValue(value: unknown): unknown {
  if (typeof value === 'string') return sanitizeString(value)
  if (Array.isArray(value)) return value.map(sanitizeValue)
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .map(([key, item]) => [key, sanitizeValue(item)]),
    )
  }
  return value
}
