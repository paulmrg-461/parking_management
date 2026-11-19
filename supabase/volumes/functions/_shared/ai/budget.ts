import type { CallerContext } from './caller.ts'
import type { AiError } from './errors.ts'
import { rpcPost } from './postgrest.ts'

export type Reservation = {
  requestId: number
  remainingRequests: number
  remainingTokens: number
}

export async function reserve(
  ctx: CallerContext,
  feature: string,
  estTokens: number,
): Promise<Reservation> {
  const result = await rpcPost(ctx, 'ai_budget_reserve', {
    p_feature: feature,
    p_est_tokens: estTokens,
  })
  if (!result.ok) {
    throw result.error
  }
  const body = result.body as Record<string, unknown>
  return {
    requestId: Number(body.request_id),
    remainingRequests: Number(body.remaining_requests),
    remainingTokens: Number(body.remaining_tokens),
  }
}

export async function record(
  ctx: CallerContext,
  requestId: number,
  usage: Record<string, unknown>,
): Promise<void> {
  // A failing usage record must never change the user-facing answer.
  try {
    await rpcPost(ctx, 'ai_usage_record', {
      p_request_id: requestId,
      p_usage: usage,
    })
  } catch (_) {
    // swallowed by design
  }
}

export async function status(
  ctx: CallerContext,
  feature: string,
): Promise<Record<string, unknown> | null> {
  const result = await rpcPost(ctx, 'ai_budget_status', { p_feature: feature })
  return result.ok ? result.body as Record<string, unknown> : null
}

export type { AiError }
