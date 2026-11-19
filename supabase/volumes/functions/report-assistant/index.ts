import { loadConfig } from '../_shared/ai/config.ts'
import { callerFrom } from '../_shared/ai/caller.ts'
import { createModelClient } from '../_shared/ai/deepseek.ts'
import { rpcPost, rpcGet, restGet } from '../_shared/ai/postgrest.ts'
import { createHandler, type HandlerDeps } from './handler.ts'

function realDeps(): HandlerDeps {
  const env = Deno.env.toObject()
  const cfg = loadConfig(env)
  const anonKey = env.SUPABASE_ANON_KEY ?? ''
  return {
    cfg,
    model: createModelClient(cfg),
    anonKey,
    rpcGet: (caller, name, args, timeoutMs) =>
      rpcGet(caller, name, args, { timeoutMs }),
    restGet: (caller, path) => restGet(caller, path).then((result) => {
      if (!result.ok) throw result.error
      return result.body
    }),
    reserve: async (caller, feature, tokens) => {
      const result = await rpcPost(caller, 'ai_budget_reserve', {
        p_feature: feature,
        p_est_tokens: tokens,
      })
      if (!result.ok) throw result.error
      const body = result.body as Record<string, unknown>
      return { requestId: Number(body.request_id) }
    },
    record: async (caller, requestId, usage) => {
      try {
        await rpcPost(caller, 'ai_usage_record', {
          p_request_id: requestId,
          p_usage: usage,
        })
      } catch (_) {
        // never break the answer
      }
    },
    status: async (caller, feature) => {
      const result = await rpcPost(caller, 'ai_budget_status', {
        p_feature: feature,
      })
      if (!result.ok) throw result.error
      return result.body as Record<string, unknown>
    },
    now: () => new Date(),
  }
}

if (import.meta.main) {
  Deno.serve(createHandler(realDeps()))
}

export { callerFrom }
