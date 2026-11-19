export type TextBlock = { type: 'text'; text: string }
export type ToolUseBlock = { type: 'tool_use'; id: string; name: string; input: unknown }
export type ToolResultBlock = {
  type: 'tool_result'
  tool_use_id: string
  content: string
  is_error?: boolean
}
export type ContentBlock = TextBlock | ToolUseBlock | ToolResultBlock

export type ModelMessage = {
  role: 'user' | 'assistant'
  content: string | ContentBlock[]
}

export type ToolDefinition = {
  name: string
  description: string
  input_schema: Record<string, unknown>
}

export type ModelParams = {
  model: string
  max_tokens: number
  system: string
  messages: ModelMessage[]
  tools: ToolDefinition[]
  tool_choice: 'auto'
}

export type ModelUsage = {
  input: number
  output: number
  cacheRead: number
  cacheWrite: number
  total: number
}

export type ModelResult = {
  content: ContentBlock[]
  stop_reason: 'end_turn' | 'tool_use' | 'max_tokens' | 'refusal'
  usage: ModelUsage
  model: string
}

export interface ModelClient {
  readonly name: string
  create(params: ModelParams, signal?: AbortSignal): Promise<ModelResult>
}
