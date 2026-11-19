// Fiscal outbox dispatcher: claims due documents and submits them through a
// provider, or polls the ones already sent. Service-role only; without
// provider credentials it answers `configured: false` and touches nothing, so
// the documents stay `pending` for the admin screen.
//
// ASSUMPTION: the provider contract and every DIAN rule; see
// openspec/changes/add-electronic-invoicing/design.md.

import type { FiscalProvider, FiscalResult } from '../_shared/fiscal_provider.ts'
import {
  errorName,
  json,
  logLine,
  type RpcResult,
  serviceRpc,
} from '../_shared/http.ts'
import { RestFiscalProvider } from '../_shared/rest_fiscal_provider.ts'

export type FiscalDispatchDeps = {
  provider: FiscalProvider
  serviceKey: () => string
  rpc: (name: string, params: Record<string, unknown>) => Promise<RpcResult>
}

type ClaimedDocument = {
  id: number
  status: 'pending' | 'sent' | string
  provider_document_id: string | null
  payload: {
    lot_id?: number
    document?: { type?: string; full_number?: string; prefix?: string; number?: number }
    source?: { id?: number }
  }
}

function defaultDeps(): FiscalDispatchDeps {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const provider = new RestFiscalProvider({
    url: Deno.env.get('FISCAL_PROVIDER_URL') ?? '',
    token: Deno.env.get('FISCAL_PROVIDER_TOKEN') ?? '',
    environment: Deno.env.get('FISCAL_PROVIDER_ENV') === 'produccion'
      ? 'produccion'
      : 'habilitacion',
    timeoutMs: Number(Deno.env.get('FISCAL_PROVIDER_TIMEOUT_MS') ?? '15000') || 15000,
  })
  return {
    provider,
    serviceKey: () => serviceKey,
    rpc: (name, params) => serviceRpc(supabaseUrl, serviceKey, name, params),
  }
}

function idempotencyKey(document: ClaimedDocument): string {
  const doc = document.payload?.document
  const lot = document.payload?.lot_id ?? ''
  return `${lot}-${doc?.full_number ?? document.id}-${doc?.type ?? 'pos'}`
}

export async function handle(
  req: Request,
  deps: FiscalDispatchDeps = defaultDeps(),
): Promise<Response> {
  const startedAt = Date.now()
  const done = (body: Record<string, unknown>, status = 200) => {
    logLine('fiscal-dispatch', startedAt, status, body)
    return json(body, status)
  }

  const authorization = req.headers.get('Authorization') ?? ''
  if (deps.serviceKey() === '' || authorization !== `Bearer ${deps.serviceKey()}`) {
    return done({ message: 'Forbidden' }, 403)
  }
  if (!deps.provider.isConfigured()) {
    return done({ configured: false, claimed: 0 })
  }

  const claimed = await deps.rpc('claim_fiscal_documents', { p_limit: 20 })
  if (!claimed.ok) {
    const name = errorName(claimed.body)
    console.error(JSON.stringify({
      fn: 'fiscal-dispatch',
      rpc: 'claim_fiscal_documents',
      status: claimed.status,
      error: name,
    }))
    return done({ configured: true, claimed: 0 }, 500)
  }

  const documents = Array.isArray(claimed.body)
    ? claimed.body as ClaimedDocument[]
    : []
  const counters = { accepted: 0, rejected: 0, retried: 0, failed: 0 }

  for (const document of documents) {
    let result: FiscalResult
    try {
      if (document.status === 'sent' && document.provider_document_id) {
        result = await deps.provider.query(document.provider_document_id)
      } else {
        result = await deps.provider.submit(
          document.payload,
          idempotencyKey(document),
        )
      }
    } catch (_) {
      result = { outcome: 'transient_error', error: 'provider call failed' }
    }

    const recorded = await deps.rpc('record_fiscal_result', {
      p_document_id: document.id,
      p_result: result,
    })
    if (!recorded.ok) {
      counters.failed += 1
      continue
    }
    switch (result.outcome) {
      case 'accepted':
        counters.accepted += 1
        break
      case 'rejected':
        counters.rejected += 1
        break
      case 'transient_error':
        counters.retried += 1
        break
      default:
        break
    }
  }

  return done({
    configured: true,
    claimed: documents.length,
    ...counters,
  })
}

if (import.meta.main) {
  Deno.serve((req) => handle(req))
}
