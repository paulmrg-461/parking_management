// Generic REST adapter for a "proveedor tecnologico". Contract:
//   POST {url}/v1/documents            (canonical payload, Idempotency-Key)
//   GET  {url}/v1/documents/{id}
// Answer: { id, status: accepted|rejected|processing, cufe, qr, errors[] }.
// A real provider with another shape gets its own FiscalProvider class; the
// SQL payload does not change.
//
// ASSUMPTION: the DIAN customer-document and payment-means code maps below are
// written from general knowledge, not verified against the current annexes.

import type { FiscalProvider, FiscalResult } from './fiscal_provider.ts'

// ASSUMPTION: DIAN customer document type codes.
export const CUSTOMER_DOCUMENT_CODES: Record<string, string> = {
  CC: '13',
  NIT: '31',
  CE: '22',
  PP: '41',
  TI: '12',
  RC: '11',
  TE: '21',
  DIE: '42',
}

// ASSUMPTION: DIAN payment means codes.
export const PAYMENT_MEANS_CODES: Record<string, string> = {
  cash: '10',
  card: '48',
  debit: '49',
  transfer: '47',
  online: 'ZZZ',
}

export type RestFiscalOptions = {
  url: string
  token: string
  environment: 'habilitacion' | 'produccion'
  timeoutMs: number
  fetchImpl?: typeof fetch
}

type ProviderAnswer = {
  id?: string
  status?: string
  cufe?: string
  qr?: string
  errors?: Array<{ code?: string; message?: string }>
}

export class RestFiscalProvider implements FiscalProvider {
  readonly name = 'rest'
  private readonly options: RestFiscalOptions

  constructor(options: RestFiscalOptions) {
    this.options = options
  }

  isConfigured(): boolean {
    return this.options.url.trim() !== '' && this.options.token.trim() !== ''
  }

  async submit(payload: unknown, idempotencyKey: string): Promise<FiscalResult> {
    return this.request('POST', '/v1/documents', payload, idempotencyKey)
  }

  async query(providerDocumentId: string): Promise<FiscalResult> {
    return this.request(
      'GET',
      `/v1/documents/${encodeURIComponent(providerDocumentId)}`,
      undefined,
      null,
    )
  }

  private async request(
    method: 'GET' | 'POST',
    path: string,
    body: unknown,
    idempotencyKey: string | null,
  ): Promise<FiscalResult> {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), this.options.timeoutMs)
    const headers: Record<string, string> = {
      Authorization: `Bearer ${this.options.token}`,
      Accept: 'application/json',
    }
    if (body !== undefined) {
      headers['Content-Type'] = 'application/json'
      headers['Idempotency-Key'] = idempotencyKey ?? ''
    }
    const payload = body === undefined
      ? undefined
      : JSON.stringify(this.withEnvironment(body))

    try {
      const response = await (this.options.fetchImpl ?? fetch)(
        `${this.options.url.replace(/\/$/, '')}${path}`,
        { method, headers, body: payload, signal: controller.signal },
      )
      const text = await response.text()
      let answer: ProviderAnswer = {}
      try {
        answer = text ? JSON.parse(text) as ProviderAnswer : {}
      } catch (_) {
        answer = {}
      }
      return this.mapAnswer(response.status, answer)
    } catch (error) {
      // Never include the token or the request headers in the stored error.
      const message = error instanceof Error && error.name === 'AbortError'
        ? 'provider timeout'
        : 'provider network error'
      return { outcome: 'transient_error', error: message }
    } finally {
      clearTimeout(timer)
    }
  }

  private withEnvironment(body: unknown): unknown {
    if (body === null || typeof body !== 'object') {
      return body
    }
    const clone = structuredClone(body) as Record<string, unknown>
    const document = clone.document
    if (document && typeof document === 'object') {
      (document as Record<string, unknown>).environment = this.options.environment
    }
    return clone
  }

  private mapAnswer(status: number, answer: ProviderAnswer): FiscalResult {
    const errors = Array.isArray(answer.errors) ? answer.errors : []
    const joined = errors
      .map((item) => item.message ?? item.code ?? '')
      .filter((value) => value !== '')
      .join('; ')

    if (status === 408 || status === 429 || status >= 500) {
      return { outcome: 'transient_error', error: `provider status ${status}` }
    }
    if (status >= 400) {
      return {
        outcome: 'rejected',
        rejectionReason: joined || `provider status ${status}`,
        providerDocumentId: answer.id,
      }
    }
    if (answer.status === 'processing') {
      return { outcome: 'pending', providerDocumentId: answer.id }
    }
    if (answer.status === 'rejected') {
      return {
        outcome: 'rejected',
        rejectionReason: joined || 'rejected',
        providerDocumentId: answer.id,
      }
    }
    if (answer.status === 'accepted') {
      return {
        outcome: 'accepted',
        providerDocumentId: answer.id,
        cufe: answer.cufe,
        qrData: answer.qr,
      }
    }
    return { outcome: 'transient_error', error: 'unexpected provider answer' }
  }
}
