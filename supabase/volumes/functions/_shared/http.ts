// Small HTTP helpers shared by the payment Edge Functions. Same conventions
// as `public-booking` and `whatsapp-dispatch`: JSON bodies, CORS, one
// structured log line per request and typed error names passed through.

export const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })

export function logLine(
  fn: string,
  startedAt: number,
  status: number,
  extra: Record<string, unknown> = {},
): void {
  console.log(JSON.stringify({
    fn,
    status,
    ms: Date.now() - startedAt,
    ...extra,
  }))
}

export type RpcResult = { ok: boolean; status: number; body: unknown }

// Service-key PostgREST call. `path` is relative to `/rest/v1/`.
export async function serviceRest(
  supabaseUrl: string,
  serviceKey: string,
  path: string,
  init: RequestInit = {},
): Promise<RpcResult> {
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  })
  const text = await response.text()
  let body: unknown = null
  try {
    body = text ? JSON.parse(text) : null
  } catch (_) {
    body = null
  }
  return { ok: response.ok, status: response.status, body }
}

export function serviceRpc(
  supabaseUrl: string,
  serviceKey: string,
  rpc: string,
  params: Record<string, unknown>,
): Promise<RpcResult> {
  return serviceRest(supabaseUrl, serviceKey, `rpc/${rpc}`, {
    method: 'POST',
    body: JSON.stringify(params),
  })
}

// A typed error name crosses the wire; anything else is hidden.
export function errorName(body: unknown): string | null {
  const message = (body as { message?: unknown } | null)?.message
  return typeof message === 'string' && /^[A-Za-z]+Error$/.test(message)
    ? message
    : null
}
