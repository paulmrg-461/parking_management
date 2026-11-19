// Typed AI errors. Names end in `Error`, matching the Flutter mapper contract.
export class AiError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
    message = code,
  ) {
    super(message)
    this.name = code
  }
}

export const aiErrors = {
  unavailable: () => new AiError('AiUnavailableError', 503),
  budget: () => new AiError('AiBudgetExceededError', 429),
  busy: () => new AiError('AiBusyError', 429),
  question: () => new AiError('AiQuestionInvalidError', 400),
  timeout: () => new AiError('AiTimeoutError', 504),
  upstream: () => new AiError('AiUpstreamError', 502),
  refused: () => new AiError('AiRefusedError', 422),
  answer: () => new AiError('AiAnswerInvalidError', 422),
  iteration: () => new AiError('AiIterationLimitError', 422),
  tokens: () => new AiError('AiTokenLimitError', 422),
}

const STATUS: Record<string, number> = {
  InvalidTokenError: 401,
  AdminRequiredError: 403,
  LotRequiredError: 400,
  AiUnavailableError: 503,
  AiBudgetExceededError: 429,
  AiQuestionInvalidError: 400,
  AiBusyError: 429,
  AiTimeoutError: 504,
  AiUpstreamError: 502,
  AiRefusedError: 422,
  AiAnswerInvalidError: 422,
  AiIterationLimitError: 422,
  AiTokenLimitError: 422,
}

export function fromPostgrest(status: number, body: unknown): AiError {
  const message = (body as { message?: unknown } | null)?.message
  if (typeof message === 'string' && STATUS[message] !== undefined) {
    return new AiError(message, STATUS[message])
  }
  // Never leak the upstream body or a service key into the client error.
  return new AiError('AiUpstreamError', status >= 500 ? 502 : 502)
}
