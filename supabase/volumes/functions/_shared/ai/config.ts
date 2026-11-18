// Runtime configuration. The provider is OpenAI-compatible (DeepSeek) and the
// feature is inert when the key is empty. No Anthropic SDK is required.
export type AiConfig = {
  provider: 'deepseek'
  apiKey: string
  baseUrl: string
  model: string
  maxIterations: number
  maxToolCalls: number
  deadlineMs: number
  rpcTimeoutMs: number
  maxOutputTokens: number
  maxTokensPerRequest: number
  modelTimeoutMs: number
}

function int(value: string | undefined, fallback: number): number {
  const parsed = Number(value ?? '')
  return Number.isFinite(parsed) && parsed > 0 ? Math.trunc(parsed) : fallback
}

export function toConfig(env: Record<string, string | undefined>): AiConfig {
  return {
    provider: 'deepseek',
    apiKey: (env.DEEPSEEK_API_KEY ?? '').trim(),
    baseUrl: (env.DEEPSEEK_BASE_URL ?? 'https://api.deepseek.com').replace(/\/$/, ''),
    model: (env.DEEPSEEK_MODEL_REPORT_ASSISTANT ?? 'deepseek-chat').trim(),
    maxIterations: int(env.AI_REPORT_MAX_ITERATIONS, 6),
    maxToolCalls: int(env.AI_REPORT_MAX_TOOL_CALLS, 12),
    deadlineMs: int(env.AI_REPORT_DEADLINE_MS, 90_000),
    rpcTimeoutMs: int(env.AI_REPORT_RPC_TIMEOUT_MS, 8_000),
    maxOutputTokens: int(env.AI_REPORT_MAX_OUTPUT_TOKENS, 4_096),
    maxTokensPerRequest: int(env.AI_REPORT_MAX_TOKENS_PER_REQUEST, 60_000),
    modelTimeoutMs: int(env.AI_MODEL_TIMEOUT_MS, 45_000),
  }
}

export const loadConfig = toConfig

export function isConfigured(cfg: AiConfig): boolean {
  return cfg.apiKey !== ''
}
