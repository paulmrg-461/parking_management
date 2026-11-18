import type { AiConfig } from '../_shared/ai/config.ts'
import { Deadline } from '../_shared/ai/deadline.ts'
import { AiError, aiErrors } from '../_shared/ai/errors.ts'
import type { ModelClient, ModelMessage, ToolUseBlock } from '../_shared/ai/types.ts'
import { validateAnswer, type IssuedResult } from './answer.ts'
import { computeOp } from './figures/ops.ts'
import { capBytes, redact, sanitizeValue } from './privacy.ts'
import {
  contextBlock,
  SUBMIT_ANSWER_TOOL,
  SYSTEM_PROMPT,
} from './prompt.ts'
import { findTool, TOOL_REGISTRY, validateArgs } from './tools/registry.ts'

export type AskRequest = {
  question: string
  locale: 'es' | 'en'
  history: Array<{ q: string; a: string }>
}

export type AgentDeps = {
  cfg: AiConfig
  model: ModelClient
  rpcGet: (
    name: string,
    args: Record<string, string | number>,
    timeoutMs: number,
  ) => Promise<
    | { ok: true; body: unknown }
    | { ok: false; error: AiError }
  >
  restGet: (path: string) => Promise<unknown>
  now: () => Date
}

export type Emit = (event: string, data: unknown) => void

export type RunOutcome = {
  status: string
  errorCode: string | null
  usage: { input: number; output: number; cacheRead: number; cacheWrite: number; total: number }
  toolCalls: number
  iterations: number
  model: string
}

function localToday(now: Date, timezone: string): string {
  try {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(now)
  } catch (_) {
    return now.toISOString().slice(0, 10)
  }
}

export async function run(
  request: AskRequest,
  deps: AgentDeps,
  emit: Emit,
  reservation: { requestId: number },
): Promise<RunOutcome> {
  const cfg = deps.cfg
  const deadline = new Deadline(cfg.deadlineMs)
  const started = Date.now()
  const usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 }
  let toolCalls = 0
  let iterations = 0
  let repaired = false
  let outcome: RunOutcome = {
    status: 'error',
    errorCode: 'AiUpstreamError',
    usage,
    toolCalls,
    iterations,
    model: cfg.model,
  }

  const { text: question } = redact(request.question)
  const history = request.history.map((turn) => ({
    q: redact(turn.q).text,
    a: redact(turn.a).text,
  }))
  const settingsRaw = await deps.restGet(
    'parking_settings?select=business_timezone,currency&limit=1',
  )
  const settings = Array.isArray(settingsRaw)
    ? settingsRaw[0] as { business_timezone?: string; currency?: string }
    : (settingsRaw ?? {}) as { business_timezone?: string; currency?: string }
  const timezone = settings.business_timezone ?? 'America/Bogota'
  const today = localToday(deps.now(), timezone)

  const messages: ModelMessage[] = [{
    role: 'user',
    content: contextBlock(settings, today, request.locale, history, question),
  }]
  const issued = new Map<string, IssuedResult>()

  const tools = [
    ...TOOL_REGISTRY.filter((tool) => tool.enabled).map((tool) => ({
      name: tool.name,
      description: tool.description,
      input_schema: tool.input_schema,
    })),
    {
      name: SUBMIT_ANSWER_TOOL.name,
      description: SUBMIT_ANSWER_TOOL.description,
      input_schema: SUBMIT_ANSWER_TOOL.input_schema,
    },
  ]

  try {
    while (true) {
      iterations += 1
      if (iterations > cfg.maxIterations + 1) throw aiErrors.iteration()
      if (deadline.remaining() <= 0) throw deadline.timeout()

      const result = await deps.model.create({
        model: cfg.model,
        max_tokens: cfg.maxOutputTokens,
        system: SYSTEM_PROMPT,
        messages,
        tools,
        tool_choice: 'auto',
      }, deadline.signal)
      outcome.model = result.model
      usage.input += result.usage.input
      usage.output += result.usage.output
      usage.cacheRead += result.usage.cacheRead
      usage.cacheWrite += result.usage.cacheWrite
      usage.total += result.usage.total
      if (usage.total > cfg.maxTokensPerRequest) throw aiErrors.tokens()
      if (result.stop_reason === 'refusal') throw aiErrors.refused()
      if (result.stop_reason === 'max_tokens') throw aiErrors.answer()

      messages.push({ role: 'assistant', content: result.content })
      const uses = result.content.filter(
        (block): block is ToolUseBlock => block.type === 'tool_use',
      )
      const submit = uses.find((block) => block.name === 'submit_answer')

      if (submit) {
        const check = validateAnswer(submit.input, issued)
        if (check.ok) {
          emit('answer', {
            ...check.answer,
            currency: settings.currency ?? 'COP',
            timezone,
            question_redacted: question !== request.question,
            request_id: reservation.requestId,
          })
          outcome = {
            ...outcome,
            status: 'ok',
            errorCode: null,
            usage,
            toolCalls,
            iterations,
          }
          emit('done', {
            iterations,
            tool_calls: toolCalls,
            input_tokens: usage.input,
            output_tokens: usage.output,
          })
          return outcome
        }
        if (repaired) throw aiErrors.answer()
        repaired = true
        const toolResults = await runOtherUses(
          uses.filter((block) => block.name !== 'submit_answer'),
          deps,
          issued,
          deadline,
          emit,
        )
        messages.push({
          role: 'user',
          content: [
            ...toolResults,
            {
              type: 'tool_result',
              tool_use_id: submit.id,
              is_error: true,
              content: JSON.stringify({
                error: 'ANSWER_REJECTED',
                problems: check.problems,
              }),
            },
          ],
        })
        continue
      }

      if (uses.length === 0) {
        if (repaired) throw aiErrors.answer()
        repaired = true
        messages.push({ role: 'user', content: 'Finish by calling submit_answer.' })
        continue
      }

      toolCalls += uses.length
      if (toolCalls > cfg.maxToolCalls) throw aiErrors.iteration()
      const results = await runOtherUses(uses, deps, issued, deadline, emit)
      messages.push({ role: 'user', content: results })
    }
  } catch (error) {
    const code = error instanceof AiError ? error.code : 'AiUpstreamError'
    outcome = {
      ...outcome,
      status: 'error',
      errorCode: code,
      usage,
      toolCalls,
      iterations,
    }
    emit('error', { code })
    emit('done', {
      iterations,
      tool_calls: toolCalls,
      input_tokens: usage.input,
      output_tokens: usage.output,
    })
    return outcome
  } finally {
    void started
  }
}

async function runOtherUses(
  uses: ToolUseBlock[],
  deps: AgentDeps,
  issued: Map<string, IssuedResult>,
  deadline: Deadline,
  emit: Emit,
): Promise<Array<{
  type: 'tool_result'
  tool_use_id: string
  content: string
  is_error?: boolean
}>> {
  const results = []
  for (const use of uses) {
    const spec = findTool(use.name)
    if (!spec) {
      issued.set(use.id, {
        callId: use.id,
        rpc: '',
        args: {},
        projected: null,
        tool: {
          name: use.name,
          rpc: '',
          description: '',
          args: {},
          input_schema: {},
          project: () => null,
          leafUnits: {},
          enabled: false,
        },
        error: 'UNKNOWN_TOOL',
      })
      results.push({
        type: 'tool_result' as const,
        tool_use_id: use.id,
        is_error: true,
        content: JSON.stringify({ error: 'UNKNOWN_TOOL' }),
      })
      continue
    }
    const validated = validateArgs(spec, use.input)
    if (!validated.ok) {
      issued.set(use.id, {
        callId: use.id,
        rpc: spec.rpc,
        args: {},
        projected: null,
        tool: spec,
        error: 'INVALID_ARGUMENT',
      })
      results.push({
        type: 'tool_result' as const,
        tool_use_id: use.id,
        is_error: true,
        content: JSON.stringify({
          error: 'INVALID_ARGUMENT',
          detail: validated.detail,
        }),
      })
      continue
    }
    emit('tool', {
      call_id: use.id,
      tool: spec.name,
      rpc: spec.rpc,
      args: validated.args,
      state: 'running',
    })
    const response = await deps.rpcGet(
      spec.rpc,
      validated.args,
      deps.cfg.rpcTimeoutMs,
    )
    if (!response.ok) {
      if (response.error.code === 'AdminRequiredError') {
        throw response.error
      }
      const code = response.error.code
      issued.set(use.id, {
        callId: use.id,
        rpc: spec.rpc,
        args: validated.args,
        projected: null,
        tool: spec,
        error: code,
      })
      emit('tool', {
        call_id: use.id,
        state: 'error',
        code,
      })
      results.push({
        type: 'tool_result' as const,
        tool_use_id: use.id,
        is_error: true,
        content: JSON.stringify({ error: code }),
      })
      continue
    }
    const projected = sanitizeValue(spec.project(response.body))
    const content = capBytes(projected)
    if (content === null) {
      issued.set(use.id, {
        callId: use.id,
        rpc: spec.rpc,
        args: validated.args,
        projected: null,
        tool: spec,
        error: 'RESULT_TOO_LARGE',
      })
      emit('tool', { call_id: use.id, state: 'error', code: 'RESULT_TOO_LARGE' })
      results.push({
        type: 'tool_result' as const,
        tool_use_id: use.id,
        is_error: true,
        content: JSON.stringify({ error: 'RESULT_TOO_LARGE' }),
      })
      continue
    }
    issued.set(use.id, {
      callId: use.id,
      rpc: spec.rpc,
      args: validated.args,
      projected,
      tool: spec,
    })
    emit('tool', {
      call_id: use.id,
      state: 'done',
      ms: Math.max(deadline.maxMs - deadline.remaining(), 0),
    })
    results.push({
      type: 'tool_result' as const,
      tool_use_id: use.id,
      content,
    })
  }
  return results
}

export { computeOp }
