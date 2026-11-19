import { AiError } from './errors.ts'

export class Deadline {
  readonly signal: AbortSignal
  private readonly controller = new AbortController()
  private readonly endsAt: number
  private readonly totalMs: number
  private readonly startedAt = Date.now()

  constructor(totalMs: number) {
    this.totalMs = totalMs
    this.endsAt = Date.now() + totalMs
    this.signal = this.controller.signal
  }

  remaining(): number {
    return Math.max(this.endsAt - Date.now(), 0)
  }

  elapsed(): number {
    return Date.now() - this.startedAt
  }

  timeout(): AiError {
    this.controller.abort()
    return new AiError('AiTimeoutError', 504)
  }

  get maxMs(): number {
    return this.totalMs
  }
}
