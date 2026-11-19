// OpenAI-compatible chat-completions adapter (DeepSeek). The canonical loop
// uses Anthropic-style content blocks; this adapter translates both ways so
// the agent, answer validator and SSE contracts stay provider-neutral.
import type { AiConfig } from './config.ts'
import { AiError } from './errors.ts'
import type {
  ContentBlock,
  ModelClient,
  ModelParams,
  ModelResult,
  ModelUsage,
  ToolUseBlock,
} from './types.ts'

type OpenAiMessage = Record<string, unknown>

const zeroUsage: ModelUsage = {
  input: 0,
  output: 0,
  cacheRead: 0,
  cacheWrite: 0,
  total: 0,
}

function toOpenAiMessages(params: ModelParams): OpenAiMessage[] {
  const messages: OpenAiMessage[] = [{ role: 'system', content: params.system }]
  for (const message of params.messages) {
    if (typeof message.content === 'string') {
      messages.push({ role: message.role, content: message.content })
      continue
    }
    if (message.role === 'assistant') {
      const text = message.content
        .filter((block): block is Extract<ContentBlock, { type: 'text' }> =>
          block.type === 'text')
        .map((block) => block.text)
        .join('')
      const toolCalls = message.content
        .filter((block): block is ToolUseBlock => block.type === 'tool_use')
        .map((block) => ({
          id: block.id,
          type: 'function',
          function: {
            name: block.name,
            arguments: JSON.stringify(block.input ?? {}),
          },
        }))
      const payload: OpenAiMessage = { role: 'assistant', content: text }
      if (toolCalls.length > 0) {
        payload.tool_calls = toolCalls
      }
      messages.push(payload)
      continue
    }
    for (const block of message.content) {
      if (block.type === 'tool_result') {
        messages.push({
          role: 'tool',
          tool_call_id: block.tool_use_id,
          content: block.content,
        })
      } else if (block.type === 'text') {
        messages.push({ role: 'user', content: block.text })
      }
    }
  }
  return messages
}

function toOpenAiTools(params: ModelParams): unknown[] {
  return params.tools.map((tool) => ({
    type: 'function',
    function: {
      name: tool.name,
      description: tool.description,
      parameters: tool.input_schema,
    },
  }))
}

function usageOf(raw: Record<string, unknown>): ModelUsage {
  const input = Number(raw.prompt_tokens ?? 0)
  const output = Number(raw.completion_tokens ?? 0)
  return {
    ...zeroUsage,
    input,
    output,
    total: input + output,
  }
}

export class DeepSeekClient implements ModelClient {
  readonly name = 'deepseek'

  constructor(private readonly config: AiConfig) {}

  async create(params: ModelParams, signal?: AbortSignal): Promise<ModelResult> {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), this.config.modelTimeoutMs)
    const abort = () => controller.abort()
    signal?.addEventListener('abort', abort)
    try {
      const response = await fetch(`${this.config.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.config.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: params.model,
          max_tokens: params.max_tokens,
          messages: toOpenAiMessages(params),
          tools: toOpenAiTools(params),
          tool_choice: 'auto',
        }),
        signal: controller.signal,
      })
      if (!response.ok) {
        throw new AiError('AiUpstreamError', 502)
      }
      const body = await response.json() as {
        model?: string
        choices?: Array<{
          finish_reason?: string
          message?: {
            content?: string | null
            tool_calls?: Array<{
              id?: string
              function?: { name?: string; arguments?: string }
            }>
          }
        }>
        usage?: Record<string, unknown>
      }
      const choice = body.choices?.[0]
      if (!choice?.message) {
        throw new AiError('AiUpstreamError', 502)
      }
      const content: ContentBlock[] = []
      if (choice.message.content) {
        content.push({ type: 'text', text: choice.message.content })
      }
      for (const call of choice.message.tool_calls ?? []) {
        if (!call.id || !call.function?.name) {
          continue
        }
        let input: unknown = {}
        try {
          input = JSON.parse(call.function.arguments ?? '{}')
        } catch (_) {
          input = {}
        }
        content.push({
          type: 'tool_use',
          id: call.id,
          name: call.function.name,
          input,
        })
      }
      const reason = choice.finish_reason
      const stop = reason === 'tool_calls'
        ? 'tool_use'
        : reason === 'length'
        ? 'max_tokens'
        : reason === 'content_filter'
        ? 'refusal'
        : 'end_turn'
      return {
        content,
        stop_reason: stop,
        usage: usageOf(body.usage ?? {}),
        model: body.model ?? params.model,
      }
    } catch (error) {
      if (error instanceof AiError) {
        throw error
      }
      throw new AiError('AiTimeoutError', 504)
    } finally {
      clearTimeout(timer)
      signal?.removeEventListener('abort', abort)
    }
  }
}

export function createModelClient(config: AiConfig): ModelClient {
  return new DeepSeekClient(config)
}
