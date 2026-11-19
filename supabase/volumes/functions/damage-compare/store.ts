// The only file that reads SUPABASE_SERVICE_ROLE_KEY. It calls exactly the two
// service-role RPCs; the model and the caller-scoped reads never see this key.
import { json } from '../_shared/ai/sse.ts'

type StoreResult = { ok: boolean; status: number }

async function serviceRpc(name: string, body: unknown): Promise<StoreResult> {
  const url = Deno.env.get('SUPABASE_URL') ?? ''
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (url === '' || key === '') {
    return { ok: false, status: 503 }
  }
  const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })
  return { ok: response.ok, status: response.status }
}

export async function storeResult(
  comparisonId: number,
  result: unknown,
  meta: Record<string, unknown>,
): Promise<boolean> {
  const response = await serviceRpc('store_damage_comparison', {
    p_comparison_id: comparisonId,
    p_result: result,
    p_meta: meta,
  })
  if (!response.ok) {
    console.error(JSON.stringify({
      fn: 'damage-compare',
      rpc: 'store_damage_comparison',
      status: response.status,
    }))
  }
  return response.ok
}

export async function failComparison(
  comparisonId: number,
  errorCode: string,
): Promise<void> {
  // A failed fail path must not throw into the user response.
  try {
    await serviceRpc('fail_damage_comparison', {
      p_comparison_id: comparisonId,
      p_error_code: errorCode.slice(0, 64),
    })
  } catch (_) {
    // ignored by design
  }
}

export { json }
