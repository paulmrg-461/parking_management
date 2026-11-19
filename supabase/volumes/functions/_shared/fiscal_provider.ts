// Provider port for the electronic-invoicing outbox. Everything provider
// specific (DIAN codes, payload shape, authentication) lives behind this
// interface, so the SQL payload stays canonical and neutral.
//
// Every DIAN rule named here is an ASSUMPTION pending the owner's/accountant's
// confirmation (see openspec/changes/add-electronic-invoicing/design.md).

export type FiscalOutcome = 'accepted' | 'rejected' | 'pending' | 'transient_error'

export type FiscalResult = {
  outcome: FiscalOutcome
  providerDocumentId?: string
  cufe?: string
  qrData?: string
  rejectionReason?: string
  error?: string
}

export interface FiscalProvider {
  readonly name: string
  isConfigured(): boolean
  submit(payload: unknown, idempotencyKey: string): Promise<FiscalResult>
  query(providerDocumentId: string): Promise<FiscalResult>
}
