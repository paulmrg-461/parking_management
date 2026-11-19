import type { CallerContext } from './caller.ts'
import { callerHeaders } from './caller.ts'
import { fromPostgrest } from './errors.ts'

export type RpcResult = { ok: true; body: unknown } | { ok: false; error: ReturnType<typeof fromPostgrest> }

function baseUrl(): string {
  return Deno.env.get('SUPABASE_URL') ?? ''
}

async function request(
  ctx: CallerContext,
  path: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetch(`${baseUrl()}/rest/v1/${path}`, {
      ...init,
      headers: { ...callerHeaders(ctx), ...(init.headers ?? {}) },
      signal: controller.signal,
    })
  } finally {
    clearTimeout(timer)
  }
}

async function parse(response: Response): Promise<RpcResult> {
  const text = await response.text()
  let body: unknown = null
  try {
    body = text ? JSON.parse(text) : null
  } catch (_) {
    body = null
  }
  if (!response.ok) {
    return { ok: false, error: fromPostgrest(response.status, body) }
  }
  return { ok: true, body }
}

export async function rpcGet(
  ctx: CallerContext,
  name: string,
  args: Record<string, string | number>,
  options: { timeoutMs: number },
): Promise<RpcResult> {
  const query = new URLSearchParams(
    Object.entries(args).map(([key, value]) => [key, String(value)]),
  )
  try {
    const response = await request(
      ctx,
      `rpc/${name}?${query.toString()}`,
      { method: 'GET' },
      options.timeoutMs,
    )
    return await parse(response)
  } catch (_) {
    return { ok: false, error: fromPostgrest(504, { message: 'AiTimeoutError' }) }
  }
}

export async function rpcPost(
  ctx: CallerContext,
  name: string,
  body: unknown,
  timeoutMs = 8_000,
): Promise<RpcResult> {
  try {
    const response = await request(
      ctx,
      `rpc/${name}`,
      { method: 'POST', body: JSON.stringify(body) },
      timeoutMs,
    )
    return await parse(response)
  } catch (_) {
    return { ok: false, error: fromPostgrest(504, { message: 'AiTimeoutError' }) }
  }
}

export async function restGet(
  ctx: CallerContext,
  path: string,
  timeoutMs = 8_000,
): Promise<RpcResult> {
  try {
    const response = await request(ctx, path, { method: 'GET' }, timeoutMs)
    return await parse(response)
  } catch (_) {
    return { ok: false, error: fromPostgrest(504, { message: 'AiTimeoutError' }) }
  }
}
