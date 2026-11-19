## Why

Receipts are internal only (`docs/project-overview.md` section 7: "Internal receipts only. No electronic invoicing", `openspec/config.yaml`: "Receipt/ticket internal only"). A parking lot operating in Colombia that must issue DIAN electronic documents (factura electronica de venta, or the electronic POS equivalent document) cannot use the system as its only sales record, and customers (companies, fleets, monthly-pass holders) ask for an invoice with their NIT. The project has no tax model at all: `amount_charged` is a single integer, `docs/project-overview.md` states "single tax regime, no tax engine".

> **Regulatory assumptions.** Every DIAN rule, code and format named in these artifacts (document types, resolution fields, CUFE/CUDE, IVA treatment, customer document type codes, payment means codes, rejection handling, retention) is an ASSUMPTION written from general knowledge, not verified against current DIAN technical annexes. Each one is marked `ASSUMPTION` and listed in the open questions of `design.md`. The owner and their accountant or "proveedor tecnologico" MUST confirm them before production use. The system must not be switched on in production (`mode != 'off'`) until that confirmation is recorded.

## What Changes

- **Provider-agnostic fiscal port.** An Edge Function `fiscal-dispatch` drains an async outbox of fiscal documents and submits each one to a "proveedor tecnologico" through a `FiscalProvider` port (`supabase/volumes/functions/_shared/fiscal_provider.ts`) with one generic REST adapter (`rest_fiscal_provider.ts`). The app never talks to DIAN or to the provider; the provider token lives only in the function environment.
- **Document lifecycle.** `fiscal_documents` with status `pending -> sent -> accepted | rejected`, plus `failed` after the retry budget (8 attempts, exponential backoff). CUFE/CUDE and the QR payload are stored on acceptance. Rejections and failures notify the lot admins; admins can retry (optionally correcting the customer data).
- **Numbering per lot.** `fiscal_resolutions` hold prefix, authorized range, validity dates and the next number; numbers are allocated gap-free inside the issuing transaction under a row lock; exhausted or expired resolutions refuse issuance and raise a notification before that happens.
- **Customer fiscal data, optional at check-out.** The check-out dialog gets an optional "Datos para factura" section (document type, number, name, email). With data the document is a factura electronica de venta (`invoice`); without it a POS equivalent document (`pos`) to "consumidor final".
- **Explicit tax handling (new).** Per-lot `fiscal_settings`: issuer data, tax regime, one tax rate in basis points, prices always tax-inclusive. The tax is extracted from the amount already charged (`tax = total - round(total * 10000 / (10000 + rate))`); no tax engine, no per-category rates, no withholdings.
- **Credit notes.** `request_credit_note` (lot admin) creates a full-reversal credit note for an accepted document; once the credit note is accepted the original is voided and the source can be invoiced again (correction flow). There is no "void check-out" feature in the codebase, so credit notes are admin-initiated.
- **Receipts.** Document number, CUFE and QR print on the receipt (screen, PDF, thermal) and in the history reprint once the document is accepted; before that the receipt says the electronic document is in process.
- **Inert without credentials.** With no `FISCAL_PROVIDER_*` env the function answers `{"configured": false}`, documents stay `pending` and are visible in the admin screen; with `mode = 'off'` (default) nothing is created.
- **Depends on `add-online-payments`** for the payment split (`parking_sessions.online_paid_amount`, `payment_method = 'online'`) that becomes the document's payment means.

## Capabilities

### New Capabilities

- `electronic-invoicing`: fiscal settings and tax extraction, resolutions and numbering, document issuance for sessions and pass charges, the async outbox with retries and states, customer data capture, credit notes, receipt content, provider boundary, inertness and access control.

### Modified Capabilities

- `billing`: the stored amount is declared tax-inclusive and the tax is derived from it for fiscal documents; the fare calculation itself is unchanged.

## Impact

- **Database (2 migrations, next free numbers, in this order):** `<NEXT>_fiscal_schema.sql`, `<NEXT>_fiscal_rpcs.sql`.
  - New tables `fiscal_settings`, `fiscal_resolutions`, `fiscal_documents`; immutability trigger; RLS.
  - New RPCs `fiscal_config`, `save_fiscal_settings`, `save_fiscal_resolution`, `list_fiscal_resolutions`, `issue_fiscal_document`, `fiscal_document_for_session`, `list_fiscal_documents`, `retry_fiscal_document`, `request_credit_note`, `enqueue_pending_fiscal_documents`, `claim_fiscal_documents`, `record_fiscal_result`; internal `fiscal_amounts`, `next_fiscal_number`, `fiscal_document_payload`.
  - `check_out`, `register_pass_payment` and every other existing RPC are NOT modified (issuance is a separate call; see design decision 1).
- **Edge Functions (new):** `fiscal-dispatch`, shared `_shared/fiscal_provider.ts`, `_shared/rest_fiscal_provider.ts` (the `_shared` folder is created by `add-online-payments`; if absent, create it). `supabase/jobs.sh`, `supabase/notifications-cron.sh`, `supabase/docker-compose.yml`, `supabase/.gitignore`.
- **Env keys (server only):** `FISCAL_PROVIDER_URL`, `FISCAL_PROVIDER_TOKEN`, `FISCAL_PROVIDER_ENV` (`habilitacion` | `produccion`), `FISCAL_PROVIDER_TIMEOUT_MS`.
- **Flutter:** new feature `lib/features/invoicing/` (admin route `/invoicing`, deferred); changes in `check_out` (dialog, cubit), `monthly_passes` (payment dialog), `vehicle_history` (issue from history), `lib/core/receipt`, `lib/core/widgets/receipt_card.dart`, `receipt_printing`, `lib/app/router`, `lib/app/shell`, `lib/app/di`, `notifications`, `lib/core/network/supabase_error_mapper.dart`, `lib/core/l10n/failure_messages.dart`, ARB files.
- **Docs:** `CHANGELOG.md`, `docs/project-overview.md` (section 7 no longer says "no electronic invoicing"), `docs/database.md`, `docs/architecture.md`, `docs/agent-memory.md`, `.env.example`, `docs/runbook-secrets.md`, `openspec/config.yaml` (the line "Receipt/ticket internal only (no electronic invoicing)" must be updated by the implementer).
- **Dependencies:** none added.

## Non-Goals

- Talking to the DIAN directly or acting as a provider (digital signature, XML UBL generation, certificate handling stay with the provider).
- Multiple tax rates, INC, ICA, withholdings (retenciones), tips, prices excluding tax, foreign-currency documents (COP only).
- Partial credit notes and debit notes (full reversal only).
- Contingency invoicing flows beyond the retry outbox, and "nomina"/"documento soporte".
- Emitting for sessions closed before invoicing was enabled (`fiscal_settings.started_at`).
- Invoicing `exempt` sessions, sessions with zero charge and monthly-pass stays (no money moved).
- Delivering the PDF to the customer ourselves (the provider e-mails the document to the address given; ASSUMPTION).
- Webhook from the provider (acceptance is obtained by polling `query`).
