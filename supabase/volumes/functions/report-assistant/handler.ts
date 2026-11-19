import type { AiConfig } from '../_shared/ai/config.ts'
import { isConfigured } from '../_shared/ai/config.ts'
import type { CallerContext } from '../_shared/ai/caller.ts'
import { callerFrom } from '../_shared/ai/caller.ts'
import { AiError, aiErrors, fromPostgrest } from '../_shared/ai/errors.ts'
import { logLine } from '../_shared/ai/log.ts'
import { json, sseResponse } from '../_shared/ai/sse.ts'
import type { ModelClient } from '../_shared/ai/types.ts'
import { run, type AskRequest, type RunOutcome } from './agent.ts'

export type HandlerDeps = {
  cfg: AiConfig
  model: ModelClient
  anonKey: string
  rpcGet: (
    caller: CallerContext,
    name: string,
    args: Record<string, string | number>,
    timeoutMs: number,
  ) => Promise<{ ok: true; body: unknown } | { ok: false; error: AiError }>
  restGet: (caller: CallerContext, path: string) => Promise<unknown>
  reserve: (
    caller: CallerContext,
    feature: string,
    tokens: number,
  ) => Promise<{ requestId: number }>
  record: (
    caller: CallerContext,
    requestId: number,
    usage: Record<string, unknown>,
  ) => Promise<void>
  status: (
    caller: CallerContext,
    feature: string,
  ) => Promise<Record<string, unknown> | null>
  now: () => Date
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-lot-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function withCors(response: Response): Response {
  for (const [key, value] of Object.entries(CORS)) {
    response.headers.set(key, value)
  }
  return response
}

function errorResponse(error: AiError): Response {
  return withCors(json({ message: error.code }, error.status))
}

function asError(error: unknown): AiError {
  return error instanceof AiError ? error : aiErrors.upstream()
}

function parseAsk(body: Record<string, unknown>): AskRequest {
  const question = String(body.question ?? '').trim()
  if (question.length < 1 || question.length > 500) {
    throw aiErrors.question()
  }
  const locale = String(body.locale ?? 'es')
  if (locale !== 'es' && locale !== 'en') throw aiErrors.question()
  const historyRaw = Array.isArray(body.history) ? body.history : []
  if (historyRaw.length > 6) throw aiErrors.question()
  const history = historyRaw.map((turn) => {
    const entry = (turn ?? {}) as Record<string, unknown>
    const q = String(entry.q ?? '').trim()
    const a = String(entry.a ?? '').trim()
    if (q.length > 500 || a.length > 400) throw aiErrors.question()
    return { q, a }
  })
  return { question, locale, history }
}

export function createHandler(deps: HandlerDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') {
      return withCors(new Response(null, { status: 204 }))
    }
    if (req.method !== 'POST') {
      return withCors(json({ message: 'MethodNotAllowed' }, 405))
    }
    const startedAt = Date.now()

    let caller: CallerContext
    let body: Record<string, unknown>
    try {
      caller = callerFrom(req, deps.anonKey)
      body = await req.json() as Record<string, unknown>
    } catch (error) {
      return errorResponse(asError(error))
    }

    const mode = String(body.mode ?? 'status')
    if (mode === 'status') {
      if (!isConfigured(deps.cfg)) {
        return withCors(json({ configured: false }))
      }
      let budget: Record<string, unknown> | null = null
      try {
        budget = await deps.status(caller, 'report_assistant')
      } catch (error) {
        if (error instanceof AiError && error.status < 500) {
          return errorResponse(error)
        }
      }
      return withCors(json({ configured: true, budget }))
    }
    if (mode !== 'ask') {
      return errorResponse(aiErrors.question())
    }

    let request: AskRequest
    try {
      request = parseAsk(body)
    } catch (error) {
      return errorResponse(asError(error))
    }

    if (!isConfigured(deps.cfg)) {
      return errorResponse(aiErrors.unavailable())
    }

    let reservation: { requestId: number }
    try {
      reservation = await deps.reserve(
        caller,
        'report_assistant',
        deps.cfg.maxTokensPerRequest,
      )
    } catch (error) {
      return errorResponse(asError(error))
    }

    const wantsSse = (req.headers.get('Accept') ?? '').includes(
      'text/event-stream',
    )
    const agent = (emit: (event: string, data: unknown) => void) =>
      run(request, {
        cfg: deps.cfg,
        model: deps.model,
        rpcGet: (name, args, timeoutMs) =>
          deps.rpcGet(caller, name, args, timeoutMs),
        restGet: (path) => deps.restGet(caller, path),
        now: deps.now,
      }, emit, reservation)

    if (!wantsSse) {
      const events: Array<{ event: string; data: unknown }> = []
      const outcome = await agent((event, data) => events.push({ event, data }))
      await deps.record(caller, reservation.requestId, usageOf(outcome))
      const answer = events.find((item) => item.event === 'answer')?.data
      if (answer === undefined) {
        return errorResponse(
          new AiError(outcome.errorCode ?? 'AiAnswerInvalidError', 422),
        )
      }
      return withCors(json({ answer, usage: usageOf(outcome) }))
    }

    return withCors(sseResponse(async (emit) => {
      emit('started', { request_id: reservation.requestId })
      const outcome = await agent(emit)
      await deps.record(caller, reservation.requestId, usageOf(outcome))
      logLine({
        fn: 'report-assistant',
        feature: 'report_assistant',
        request_id: reservation.requestId,
        lot: caller.lotId,
        status: outcome.status,
        ms: Date.now() - startedAt,
        in_tok: outcome.usage.input,
        out_tok: outcome.usage.output,
        cache_read: outcome.usage.cacheRead,
        tool_calls: outcome.toolCalls,
        iterations: outcome.iterations,
        error: outcome.errorCode,
        model: outcome.model,
      })
    }))
  }
}

function usageOf(outcome: RunOutcome): Record<string, unknown> {
  return {
    status: outcome.status === 'ok' ? 'ok' : 'error',
    model: outcome.model,
    input_tokens: outcome.usage.input,
    output_tokens: outcome.usage.output,
    cache_read_tokens: outcome.usage.cacheRead,
    cache_write_tokens: outcome.usage.cacheWrite,
    tool_calls: outcome.toolCalls,
    duration_ms: 0,
    error_code: outcome.errorCode,
  }
}

export { fromPostgrest }
