## Context

Verified against the repository on 2026-11-10 (head migration `0102`):

- `parking_sessions` (`0001` + later): `id serial, vehicle_id, operator_id, entry_time, status ('open'|'closed'), exit_time, amount_charged integer, ticket_number varchar(20) unique, payment_method (cash|card|transfer|monthly_pass|exempt; `online` added by `add-online-payments`), card_type, cash_received, cash_change, discount_amount, discount_reason, discount_by, discount_at, lost_ticket, shift_id, lot_id, closed_recorded_at`. `check_out` latest body `0072` (re-declared by `add-online-payments`, which must be implemented first) stores `amount_charged` = gross minus discount as an integer in minor units; ticket number format `TCK-<lot code>-<id padded 6>`. It is NOT modified by this change.
- `monthly_pass_payments` (`0016`, `0023`): `id, monthly_pass_id unique, amount, payment_method, status (pending|paid|waived), due_date, paid_at, paid_by, shift_id, lot_id`; `register_pass_payment` latest `0073`.
- No tax data anywhere: `parking_settings` has branding, `currency`, capacity, WhatsApp, retention columns only; `docs/project-overview.md` section 7: "Single currency and single tax regime assumptions (no per-vehicle currency, no tax engine)". `vehicles` has `owner_name`, `owner_phone` and no document number.
- No function voids, reopens or corrects a closed session (searched `supabase/migrations`); the only corrections are `adjust_shift` (cash count) and the discount audit.
- Helpers: `require_lot_admin()` (returns the lot id, raises `AdminRequiredError`), `is_lot_admin(lot_id)`, `current_lot_id()`, `require_app_user()`, `format_money(amount, currency)` (`0073`), `notifications(user_id, type, title, body, data, dedupe_key, lot_id)`.
- Receipts: `ReceiptData` (`lib/core/receipt/receipt_data.dart`), `ReceiptLabels` (`receipt_labels.dart`, ASCII-only for thermal printers), rendered by `lib/core/widgets/receipt_card.dart`, `lib/features/receipt_printing/infrastructure/esc_pos_generator.dart` (thermal) and `system_dialog_receipt_printer.dart` (PDF); the history reprint rebuilds `ReceiptData` in `lib/features/vehicle_history/presentation/vehicle_history_page.dart` (`_receipt`).
- Edge Function conventions: `whatsapp-dispatch` pattern (service key bearer, `configured:false` when inert, structured log line, `jobs.sh` `dispatch`).
- Router: admin-only deferred routes use `_deferred('<path>', lib.loadLibrary, () => lib.buildXEntry())` and a file `lib/app/router/deferred/<name>_entry.dart`; operators have an allowlist (`operatorRoutes` in `route_access.dart`), so a new route is admin-only by default. Destinations live in `lib/app/shell/app_destinations.dart`.

> `public_create_reservation` and other `public_*` RPCs may have changed while this was written; this change does not touch them.

## Goals / Non-Goals

**Goals:** a legally issued, numbered electronic document per paid stay or pass charge, created without slowing or blocking check-out; failures never lose a document; no credential, no behaviour change.

**Non-Goals:** see `proposal.md`.

## Decisions

1. **Issuance is a separate call, not part of `check_out`.** `check_out` already carries 11 parameters and is redefined by `add-online-payments`; adding fiscal parameters would create an overload trap, and offline check-outs are queued and replayed (AGENTS section 5), so customer data capture cannot ride on them. After a successful online check-out the page calls `issue_fiscal_document('session', id, customer)`; for `mode = 'always'` the scheduled sweeper `enqueue_pending_fiscal_documents` also issues a default `pos` document for any paid session or pass charge that still has none after 10 minutes (covers offline check-outs, failed calls and online-paid passes). A failure of the issuance call never fails or delays the check-out.
2. **Outbox, not inline submission.** The document row IS the outbox: `fiscal_documents.status` plus `attempts`, `next_attempt_at`, `locked_until`. `fiscal-dispatch` claims with `for update skip locked` semantics inside `claim_fiscal_documents`, submits, and reports with `record_fiscal_result`. Provider outages therefore only delay acceptance.
3. **Gap-free numbering under a lock.** `next_fiscal_number` locks the active resolution row `for update` inside the issuing transaction; a rollback releases the number. A rejected or failed document keeps its number (ASSUMPTION: DIAN accepts a corrected re-submission of the same number; the owner must confirm). Rejected alternative: numbering at submission time (a provider outage would delay numbers and break issue-date ordering).
4. **Two document types plus credit note:** `pos` (documento equivalente electronico POS, buyer "consumidor final") and `invoice` (factura electronica de venta, buyer data given), `credit_note` (nota credito, full reversal). ASSUMPTION: which of these apply to this business, and that `pos` is acceptable for parking sales, is the owner's/accountant's decision; the data model supports both.
5. **Tax: one explicit rule, prices tax-inclusive.** `fiscal_settings.tax_rate_bps` (0..10000, e.g. 1900 for 19 %, ASSUMPTION that parking services are taxed with IVA at that rate) is applied to the amount already charged. Pure function `fiscal_amounts(p_total, p_discount, p_rate_bps)` returns `{gross, discount, total, tax_base, tax_amount}` where `total = p_total`, `tax_base = round(total * 10000 / (10000 + rate))`, `tax_amount = total - tax_base`, `gross = total + discount`. Totals always equal what the customer paid, so cash reconciliation and the invoice agree. Prices excluding tax would make the document exceed the amount paid and are a non-goal.
6. **Immutable once numbered.** A `before update` trigger raises `FiscalDocumentImmutableError` if `doc_type`, `number`, `prefix`, `lot_id`, `source_kind`, `source_id`, amounts, `issued_at` or `related_document_id` change; customer columns may change only while status is `rejected` or `failed` (through `retry_fiscal_document`). No delete grant exists; documents are never purged (ASSUMPTION: retention is at least five years).
7. **Credit note + void for corrections.** `request_credit_note` creates a `credit_note` row (own numbering, own resolution) with the same amounts; when it is accepted `record_fiscal_result` stamps `voided_at` on the original, which frees the source for a new document (`uq_fiscal_source_active`). This is the correction flow (wrong customer, wrong document type).
8. **PII is not readable by operators.** Customer data lives in `fiscal_documents` (RLS: lot admins only). Operators call RPCs that return only status, number, CUFE and QR. This applies Ley 1581 (habeas data) minimisation (ASSUMPTION about the legal regime; the owner must define the privacy notice).
9. **Provider port with one adapter contract.** Everything provider specific sits behind `FiscalProvider`; the SQL payload is canonical and provider neutral. The generic adapter assumes a REST provider that accepts the canonical JSON; a real provider that needs another shape gets its own adapter class implementing the same interface (no SQL change).
10. **No overloads.** All function names are new; no existing function gains a parameter.

## Data model

### `<NEXT>_fiscal_schema.sql`

```sql
create table if not exists public.fiscal_settings (
    lot_id             integer primary key references public.parking_lots(id),
    mode               text    not null default 'off' check (mode in ('off','on_request','always')),
    issuer_nit         text,
    issuer_legal_name  text,
    tax_regime         text    not null default 'responsable_iva'
        check (tax_regime in ('responsable_iva','no_responsable_iva','simple')),
    tax_rate_bps       integer not null default 1900 check (tax_rate_bps between 0 and 10000),
    municipality_code  text,
    started_at         timestamptz,
    updated_at         timestamptz not null default now(),
    check (mode = 'off' or (issuer_nit is not null and issuer_legal_name is not null
                            and municipality_code is not null))
);

create table if not exists public.fiscal_resolutions (
    id                bigserial primary key,
    lot_id            integer not null references public.parking_lots(id),
    doc_type          text    not null check (doc_type in ('pos','invoice','credit_note')),
    resolution_number text    not null,
    prefix            text    not null default '' check (prefix ~ '^[A-Za-z0-9]{0,6}$'),
    range_from        bigint  not null check (range_from > 0),
    range_to          bigint  not null,
    next_number       bigint  not null,
    valid_from        date    not null,
    valid_to          date    not null,
    active            boolean not null default true,
    created_at        timestamptz not null default now(),
    check (range_to >= range_from and next_number >= range_from and valid_to >= valid_from)
);
create unique index if not exists uq_fiscal_resolution_active
    on public.fiscal_resolutions(lot_id, doc_type) where active;

create table if not exists public.fiscal_documents (
    id                    bigserial primary key,
    lot_id                integer not null references public.parking_lots(id),
    doc_type              text    not null check (doc_type in ('pos','invoice','credit_note')),
    resolution_id         bigint  not null references public.fiscal_resolutions(id),
    prefix                text    not null default '',
    number                bigint  not null,
    full_number           text    not null,
    source_kind           text    not null check (source_kind in ('session','pass_payment')),
    source_id             bigint  not null,
    related_document_id   bigint  references public.fiscal_documents(id),
    credit_reason         text,
    currency              text    not null default 'COP' check (currency = 'COP'),
    gross_amount          integer not null check (gross_amount >= 0),
    discount_amount       integer not null default 0 check (discount_amount >= 0),
    tax_rate_bps          integer not null check (tax_rate_bps between 0 and 10000),
    tax_base              integer not null check (tax_base >= 0),
    tax_amount            integer not null check (tax_amount >= 0),
    total                 integer not null check (total > 0),
    customer_doc_type     text check (customer_doc_type in ('CC','NIT','CE','PP','TI','RC','TE','DIE')),
    customer_doc_number   text,
    customer_name         text,
    customer_email        text,
    status                text    not null default 'pending'
        check (status in ('pending','sent','accepted','rejected','failed')),
    attempts              integer not null default 0,
    next_attempt_at       timestamptz not null default now(),
    locked_until          timestamptz,
    last_error            text,
    provider_document_id  text,
    cufe                  text,
    qr_data               text,
    rejection_reason      text,
    issued_at             timestamptz not null default now(),
    accepted_at           timestamptz,
    voided_at             timestamptz,
    created_by            integer references public.users(id),
    created_at            timestamptz not null default now(),
    updated_at            timestamptz not null default now(),
    unique (lot_id, doc_type, prefix, number),
    check ((customer_doc_type is null) = (customer_doc_number is null)),
    check (doc_type <> 'credit_note' or related_document_id is not null)
);
create unique index if not exists uq_fiscal_source_active
    on public.fiscal_documents(source_kind, source_id)
    where doc_type in ('pos','invoice') and voided_at is null;
create unique index if not exists uq_fiscal_credit_note_per_document
    on public.fiscal_documents(related_document_id)
    where doc_type = 'credit_note' and status not in ('rejected','failed');
create index if not exists ix_fiscal_queue
    on public.fiscal_documents(next_attempt_at) where status in ('pending','sent');
create index if not exists ix_fiscal_lot on public.fiscal_documents(lot_id, created_at desc);

alter table public.fiscal_settings enable row level security;
alter table public.fiscal_resolutions enable row level security;
alter table public.fiscal_documents enable row level security;
grant select on public.fiscal_settings, public.fiscal_resolutions, public.fiscal_documents to authenticated;
create policy fiscal_settings_admin_read on public.fiscal_settings for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));
create policy fiscal_resolutions_admin_read on public.fiscal_resolutions for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));
create policy fiscal_documents_admin_read on public.fiscal_documents for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));
-- No insert/update/delete policies or grants: writes go through security definer RPCs.
```

Wrap each `create policy` in `drop policy if exists ... ;` first (idempotent, as earlier migrations do). The immutability trigger and the pure helpers are in the same file:

```sql
create or replace function public.fiscal_amounts(p_total integer, p_discount integer, p_rate_bps integer)
returns jsonb language sql immutable set search_path = public as $$
    select jsonb_build_object(
        'gross', p_total + p_discount,
        'discount', p_discount,
        'total', p_total,
        'tax_base', round(p_total * 10000.0 / (10000 + p_rate_bps))::integer,
        'tax_amount', p_total - round(p_total * 10000.0 / (10000 + p_rate_bps))::integer
    );
$$;
-- trg_fiscal_documents_immutable (before update): raises 'FiscalDocumentImmutableError' when
-- any of doc_type, number, prefix, full_number, lot_id, source_kind, source_id, related_document_id,
-- gross_amount, discount_amount, tax_rate_bps, tax_base, tax_amount, total, issued_at changes,
-- or when a customer_* column changes while old.status not in ('rejected','failed').
```

Worked examples that the SQL tests pin: `fiscal_amounts(11900, 0, 1900)` -> base 10000, tax 1900; `fiscal_amounts(5000, 0, 1900)` -> base 4202, tax 798; rate 0 -> base = total, tax 0.

### `<NEXT>_fiscal_rpcs.sql`

All `language plpgsql`, `security definer`, `set search_path = public`. Edge-function and cron functions: `revoke all ... from public, anon, authenticated;` (+ `grant ... to service_role`).

| Function | Signature | Grant | Returns |
|---|---|---|---|
| `fiscal_config` | `()` | `authenticated` (`require_app_user()`) | `{mode, has_pos_resolution, has_invoice_resolution, tax_rate_bps}` for the active lot |
| `save_fiscal_settings` | `(p_settings jsonb)` | `authenticated` (`require_lot_admin()`) | the settings row as jsonb. Keys `mode, issuer_nit, issuer_legal_name, tax_regime, tax_rate_bps, municipality_code`; omitted keys keep their value; setting `mode` away from `off` for the first time stamps `started_at = now()` |
| `save_fiscal_resolution` | `(p_resolution jsonb)` | `authenticated` (`require_lot_admin()`) | the new resolution row. Keys `doc_type, resolution_number, prefix, range_from, range_to, valid_from, valid_to`; deactivates the previous active one of the same type; `next_number = range_from` |
| `list_fiscal_resolutions` | `()` | `authenticated` (`require_lot_admin()`) | array of resolutions with `remaining` (= `range_to - next_number + 1`) |
| `issue_fiscal_document` | `(p_source_kind text, p_source_id bigint, p_customer jsonb default null)` | `authenticated` (`require_app_user()` + lot membership) | `{document_id, doc_type, full_number, status, created boolean}` |
| `fiscal_document_for_session` | `(p_session_id integer)` | `authenticated` | `{document_id, doc_type, full_number, status, cufe, qr_data, total, tax_amount, issued_at}` or `null` (no customer data) |
| `list_fiscal_documents` | `(p_status text default null, p_limit integer default 50, p_offset integer default 0)` | `authenticated` (`require_lot_admin()`) | `{total, items:[{id, doc_type, full_number, status, total, tax_amount, issued_at, source_kind, source_id, customer_name, customer_doc_type, customer_doc_number, cufe, rejection_reason, last_error, attempts, voided_at}]}` ordered `id desc` (not `now()`) |
| `retry_fiscal_document` | `(p_document_id bigint, p_customer jsonb default null)` | `authenticated` (`require_lot_admin()`) | the document summary; only for `rejected`/`failed`; resets `attempts = 0`, `status = 'pending'`, `next_attempt_at = now()`, optional customer replacement |
| `request_credit_note` | `(p_document_id bigint, p_reason text)` | `authenticated` (`require_lot_admin()`) | the credit note summary |
| `enqueue_pending_fiscal_documents` | `()` | none (cron) | integer documents created |
| `claim_fiscal_documents` | `(p_limit integer default 20)` | `service_role` | `[{id, status, provider_document_id, payload}]` |
| `record_fiscal_result` | `(p_document_id bigint, p_result jsonb)` | `service_role` | `{status}` |
| `next_fiscal_number` | `(p_lot_id integer, p_doc_type text)` | none (internal) | `{resolution_id, prefix, number}` |
| `fiscal_document_payload` | `(p_document_id bigint)` | none (internal) | canonical payload (below) |

Behaviour and typed errors (names follow the repo convention `<Name>Error`):

- `issue_fiscal_document`: lot from the source row, must equal `current_lot_id()` (else `FiscalSourceNotFoundError`); mode `off` -> `FiscalNotEnabledError`; source `session` must be `closed`, `amount_charged > 0`, `payment_method <> 'exempt'`, and `closed_recorded_at >= started_at`; source `pass_payment` must be `paid` with `amount > 0` and `paid_at >= started_at`; otherwise `FiscalSourceNotBillableError`. Idempotent: an existing non-voided `pos`/`invoice` for the source is returned with `created = false` (customer data of a second call is ignored). `p_customer` shape `{document_type, document_number, name, email}`; validation: type in `CC,NIT,CE,PP,TI,RC,TE,DIE`, number `^[A-Za-z0-9]{3,20}$`, name 2..120 chars, optional email `^[^@\s]+@[^@\s]+\.[^@\s]+$` (max 120) else `InvalidFiscalCustomerError`. Customer present -> `invoice`, absent -> `pos`. Takes `pg_advisory_xact_lock(hashtext('fiscal_source'), source_id::integer)`, allocates the number with `next_fiscal_number`, computes amounts with `fiscal_amounts(total, discount, tax_rate_bps)` (session total = `amount_charged`, discount = `discount_amount`; pass total = `monthly_pass_payments.amount`, discount 0) and inserts the row.
- `next_fiscal_number`: locks the active resolution `for update`; none -> `FiscalResolutionMissingError`; `valid_to < lot local today` or `valid_from > today` -> `FiscalResolutionExpiredError`; `next_number > range_to` -> `FiscalResolutionExhaustedError`; else returns and increments.
- `request_credit_note`: reason 3..200 chars (`InvalidDataError`); original must be `accepted` and not voided (`FiscalDocumentNotAcceptedError`), not itself a credit note, and without a live credit note (`FiscalDocumentAlreadyCreditedError`, enforced by `uq_fiscal_credit_note_per_document`); allocates a `credit_note` number; copies amounts and the customer; sets `related_document_id`, `credit_reason`.
- `retry_fiscal_document`: other statuses -> `InvalidFiscalStatusError`; unknown or other lot -> `FiscalDocumentNotFoundError`.
- `enqueue_pending_fiscal_documents`: for each lot with `mode = 'always'` and an active resolution: paid sessions and paid pass charges older than 10 minutes (`closed_recorded_at` / `paid_at`), since `started_at`, with no live document, are issued as `pos`; a lot without a resolution is skipped. Then, per lot with invoicing on, it notifies lot admins `fiscal_resolution_low` when `remaining < 50` or `valid_to - today <= 30` (dedupe `'fiscal_res:' || resolution_id || ':' || local date || ':user:' || user_id`). Never uses `current_lot_id()` (cron context).
- `claim_fiscal_documents`: selects `status in ('pending','sent') and next_attempt_at <= now() and (locked_until is null or locked_until < now())` ordered by `id` with `for update skip locked`, sets `locked_until = now() + interval '5 minutes'` and `attempts = attempts + 1`, returns the payload.
- `record_fiscal_result` (`p_result` keys `outcome` = `accepted|rejected|pending|transient_error`, `provider_document_id`, `cufe`, `qr_data`, `rejection_reason`, `error`): `accepted` -> `status = 'accepted'`, `cufe`, `qr_data`, `accepted_at = now()`, and when the document is a credit note `voided_at = now()` on the original; `rejected` -> `status = 'rejected'`, `rejection_reason`, notify; `pending` -> `status = 'sent'`, `provider_document_id`, `next_attempt_at = now() + interval '1 minute'`; `transient_error` -> `last_error`, `next_attempt_at = now() + backoff(attempts)` with minutes `[1, 5, 15, 60, 240, 240, 240]`; at `attempts >= 8` -> `status = 'failed'` and notify. Notifications `fiscal_document_failed` to active lot admins, `dedupe_key = 'fiscal_fail:' || id || ':' || status || ':user:' || user_id`. `locked_until = null` after every result. `now()` is constant per transaction, so tests set `next_attempt_at`/`locked_until` explicitly.

Canonical payload from `fiscal_document_payload` (all money are integers in pesos):

```json
{
  "document": {"type": "pos|invoice|credit_note", "prefix": "SETP", "number": 1234, "full_number": "SETP1234",
               "issued_at": "2026-11-10T14:05:00-05:00", "currency": "COP",
               "environment": "habilitacion|produccion"},
  "resolution": {"number": "18760000001", "prefix": "SETP", "range_from": 1, "range_to": 5000,
                 "valid_from": "2026-01-01", "valid_to": "2027-01-01"},
  "issuer": {"nit": "900123456", "legal_name": "...", "trade_name": "...", "address": "...",
             "municipality_code": "11001", "tax_regime": "responsable_iva"},
  "customer": {"is_final_consumer": true, "document_type": "NIT", "document_number": "222222222222",
               "name": "Consumidor final", "email": null},
  "lines": [{"description": "Servicio de parqueadero ABC123", "quantity": 1,
             "unit_price": 10000, "tax_rate_bps": 1900, "tax_amount": 1900, "line_total": 11900}],
  "totals": {"gross": 11900, "discount": 0, "tax_base": 10000, "tax_amount": 1900, "total": 11900},
  "payments": [{"method": "online", "amount": 6000}, {"method": "cash", "amount": 5900}],
  "reference": {"document_full_number": null, "cufe": null, "reason": null},
  "source": {"kind": "session", "id": 55, "ticket_number": "TCK-1-000055"}
}
```

`payments` is derived from the source: for sessions `online_paid_amount` (from `add-online-payments`) as `online`, the rest with `payment_method` (`card` carries `card_type`); for passes the charge's method. `reference` is filled for credit notes (original number, CUFE, reason). The generic adapter maps methods to DIAN payment-means codes (ASSUMPTION: cash 10, credit card 48, debit card 49, bank transfer 47, other ZZZ) and customer types to DIAN codes (ASSUMPTION: CC 13, NIT 31, CE 22, PP 41, TI 12, RC 11, TE 21, DIE 42); SQL never stores DIAN codes.

## Edge Function `fiscal-dispatch`

- `POST /functions/v1/fiscal-dispatch`, `Authorization: Bearer <service role key>` only (`403 {"message":"Forbidden"}` otherwise), no body. Called from `supabase/jobs.sh` (`run enqueue_pending_fiscal_documents` then `dispatch "${API_URL}/functions/v1/fiscal-dispatch"`) and `supabase/notifications-cron.sh`.
- `FISCAL_PROVIDER_URL` or `FISCAL_PROVIDER_TOKEN` empty -> `200 {"configured": false, "claimed": 0}` and no database call (documents stay `pending`).
- Otherwise: `rpc/claim_fiscal_documents` (limit 20) -> for each document: status `pending` -> `provider.submit(payload)`; status `sent` -> `provider.query(provider_document_id)` -> `rpc/record_fiscal_result`. Per-request timeout `FISCAL_PROVIDER_TIMEOUT_MS` (default 15000). Response `200 {"configured": true, "claimed": n, "accepted": a, "rejected": r, "retried": t, "failed": f}`; a failure to read the queue is `500`.
- Port:

```ts
export type FiscalResult = {
  outcome: 'accepted' | 'rejected' | 'pending' | 'transient_error';
  providerDocumentId?: string; cufe?: string; qrData?: string;
  rejectionReason?: string; error?: string;
};
export interface FiscalProvider {
  readonly name: string;
  isConfigured(): boolean;
  submit(payload: unknown, idempotencyKey: string): Promise<FiscalResult>;
  query(providerDocumentId: string): Promise<FiscalResult>;
}
```

- Generic REST adapter contract (ASSUMPTION: replace by the real provider's mapping): `POST ${FISCAL_PROVIDER_URL}/v1/documents`, headers `Authorization: Bearer ${FISCAL_PROVIDER_TOKEN}`, `Idempotency-Key: <lot_id>-<full_number>-<type>`, body = canonical payload; `GET ${FISCAL_PROVIDER_URL}/v1/documents/<id>`; response `{"id": "...", "status": "accepted|rejected|processing", "cufe": "...", "qr": "...", "errors": [{"code": "...", "message": "..."}]}`. Mapping: 200/201 `accepted` -> `accepted`; `processing` -> `pending`; `rejected` or any 4xx except 408/429 -> `rejected` with the joined error messages; network error, timeout, 408, 429, 5xx -> `transient_error`. The token never appears in logs or in `last_error`.
- Function env (functions service only): `FISCAL_PROVIDER_URL`, `FISCAL_PROVIDER_TOKEN`, `FISCAL_PROVIDER_ENV` (`habilitacion` default | `produccion`), `FISCAL_PROVIDER_TIMEOUT_MS` (15000); passed in `supabase/docker-compose.yml` with `${VAR:-}`, documented in `.env.example` and `docs/runbook-secrets.md`; folder allowlisted in `supabase/.gitignore`.

## State machine

`pending -> sent -> accepted`; `pending|sent -> rejected` (provider/DIAN rejection; terminal until `retry_fiscal_document`); `pending|sent -> failed` (8 transient attempts; terminal until retry); `rejected|failed -> pending` (retry); `accepted` is terminal. A credit note follows the same machine; its `accepted` voids the original.

## Sequences

1. Operator check-out with fiscal data: dialog (optional section) -> `check_out` (online, unchanged) -> receipt dialog -> `issue_fiscal_document('session', id, customer)` -> receipt shows "Factura electronica en proceso" -> later `fiscal_document_for_session` (history reprint) shows number, CUFE and QR once `accepted`.
2. Offline check-out in `always` mode: replay creates the session; the sweeper issues a `pos` 10 minutes later.
3. Admin correction: `/invoicing` -> document -> "Nota credito" -> `request_credit_note` -> dispatch -> accepted -> original voided -> admin issues a new `invoice` from the session (history "Emitir factura") with the right customer.

## Flutter

New feature `lib/features/invoicing/`:

```
domain/entities/fiscal_settings.dart        // FiscalSettings{mode:FiscalMode, issuerNit, issuerLegalName, taxRegime:String, taxRateBps:int, municipalityCode}; enum FiscalMode{off,onRequest,always}
domain/entities/fiscal_resolution.dart      // FiscalResolution{id, docType:FiscalDocType, resolutionNumber, prefix, rangeFrom, rangeTo, nextNumber, validFrom, validTo, active, remaining}
domain/entities/fiscal_document.dart        // FiscalDocument{id, docType, fullNumber, status:FiscalStatus, total, taxAmount, issuedAt, sourceKind, sourceId, customerName?, customerDocType?, customerDocNumber?, cufe?, rejectionReason?, lastError?, attempts, voided}; FiscalDocSummary{documentId, docType, fullNumber, status, cufe?, qrData?, total, taxAmount, issuedAt}
domain/entities/fiscal_customer.dart        // FiscalCustomer{documentType:FiscalIdType, documentNumber, name, email?} + validation (pure)
domain/repositories/invoicing_repository.dart
application/issue_fiscal_document.dart      // use case (never throws to the check-out flow: returns FiscalDocSummary? )
application/invoicing_cubit.dart            // admin screen
infrastructure/invoicing_remote_data_source.dart, invoicing_repository_impl.dart, models/*_dto.dart
presentation/invoicing_page.dart, widgets/fiscal_customer_form.dart, widgets/fiscal_status_chip.dart
```

Repository port: `config()`, `settings()`, `saveSettings(FiscalSettings)`, `resolutions()`, `saveResolution(FiscalResolution)`, `documents({FiscalStatus? status, int limit = 50, int offset = 0})` -> `PagedResult<FiscalDocument>` (existing `core/pagination/paged_result.dart`), `retry(int id, {FiscalCustomer? customer})`, `requestCreditNote(int id, String reason)`, `issueForSession(int sessionId, {FiscalCustomer? customer})`, `issueForPassPayment(int paymentId, {FiscalCustomer? customer})`, `documentForSession(int sessionId)`. Every method is online only; offline throws `NetworkFailure` and nothing is stored in the Hive outbox.

`InvoicingState` (sealed, Equatable, 4 UI states): `InvoicingInitial`, `InvoicingLoading` (skeleton table), `InvoicingLoaded` (`documents`, `statusFilter`, `total`, `hasMore`, `settings`, `resolutions`, `submission:Submission`; an empty list is the empty state with a call to action "Configurar resolucion"), `InvoicingFailure` (message + Retry). Extends `ResilientCubit`.

Existing code changed:

- `check_out`: `CheckoutChoice` gains `fiscalCustomer:FiscalCustomer?`; `payment_method_dialog.dart` gets the collapsed section "Datos para factura" (rendered only when `fiscal_config.mode != 'off'` and the device is online); `check_out_page.dart` calls `serviceLocator<IssueFiscalDocument>()` (guarded by `isRegistered`) after a successful non-pending check-out, then passes the returned `FiscalDocSummary?` to the receipt. `CheckOutCubit` and the RPC call are not changed.
- `monthly_passes_page.dart` `_PaymentMethodDialog`: same optional section; after `registerPayment` succeeds call `issueForPassPayment`.
- `vehicle_history_page.dart`: reprint loads `documentForSession` for closed sessions; a menu action "Emitir factura electronica" opens the customer form and calls `issueForSession` (admins and operators).
- `lib/core/receipt/receipt_data.dart`: `fiscalNumber:String?`, `fiscalType:String?` (`pos|invoice`), `cufe:String?`, `fiscalQr:String?`, `fiscalPending:bool=false`; `receipt_labels.dart`: `fiscalInvoice` ("FACTURA ELECTRONICA DE VENTA"/"ELECTRONIC SALES INVOICE"), `fiscalPos` ("DOCUMENTO EQUIVALENTE POS"/"POS EQUIVALENT DOCUMENT"), `cufe` ("CUFE"), `fiscalPendingLabel` ("Documento electronico en proceso"/"Electronic document in process") ASCII only; `receipt_card.dart`, `esc_pos_generator.dart` (QR via the existing `GS ( k` routine used for the check-in QR), `system_dialog_receipt_printer.dart` (PDF `pw.BarcodeWidget`) print number, CUFE (wrapped) and QR when `fiscalQr != null`, or the pending label.
- Router: `lib/app/router/deferred/invoicing_entry.dart` (`buildInvoicingEntry()` -> `BlocProvider<InvoicingCubit>` + `InvoicingPage`), `_deferred('invoicing', invoicing.loadLibrary, () => invoicing.buildInvoicingEntry())` in `app_router.dart`; NOT added to `operatorRoutes`. `app_destinations.dart`: admin destination `/invoicing` (`navInvoicing`, `Icons.request_quote_outlined` / `Icons.request_quote`). DI: `lib/app/di/modules/invoicing_module.dart` -> `registerInvoicingModule(sl)` registered after `registerSettingsModule(sl)` in `registerAllModules`.
- `notifications`: `notification_routes.dart` maps `fiscal_document_failed` and `fiscal_resolution_low` to `/invoicing`; `notifications_page.dart` labels/icons.
- `lib/core/network/supabase_error_mapper.dart` `_domainCodes` and `FailureMessages._byCode`: `FiscalNotEnabledError, FiscalResolutionMissingError, FiscalResolutionExpiredError, FiscalResolutionExhaustedError, FiscalSourceNotFoundError, FiscalSourceNotBillableError, InvalidFiscalCustomerError, FiscalDocumentNotFoundError, FiscalDocumentNotAcceptedError, FiscalDocumentAlreadyCreditedError, InvalidFiscalStatusError, FiscalSettingsIncompleteError, FiscalDocumentImmutableError`.

### New l10n keys (ES / EN)

| Key | ES | EN |
|---|---|---|
| `navInvoicing` | Facturación | Invoicing |
| `invoicingTitle` | Facturación electrónica | Electronic invoicing |
| `invoicingMode` | Modo | Mode |
| `invoicingModeOff` | Apagada | Off |
| `invoicingModeOnRequest` | Solo a solicitud | On request |
| `invoicingModeAlways` | Siempre | Always |
| `invoicingSettings` | Datos del emisor | Issuer data |
| `invoicingNit` | NIT del emisor | Issuer NIT |
| `invoicingLegalName` | Razón social | Legal name |
| `invoicingMunicipality` | Código de municipio | Municipality code |
| `invoicingTaxRate` | Tarifa de impuesto (puntos básicos) | Tax rate (basis points) |
| `invoicingPricesIncludeTax` | Los precios ya incluyen el impuesto | Prices already include tax |
| `invoicingResolutions` | Resoluciones de numeración | Numbering resolutions |
| `invoicingResolutionAdd` | Agregar resolución | Add resolution |
| `invoicingResolutionRemaining` | Quedan {count} números | {count} numbers left |
| `invoicingDocuments` | Documentos | Documents |
| `invoicingEmpty` | Aún no hay documentos. Configura una resolución para empezar. | No documents yet. Set up a resolution to begin. |
| `invoicingStatusPending` | Pendiente | Pending |
| `invoicingStatusSent` | Enviado | Sent |
| `invoicingStatusAccepted` | Aceptado | Accepted |
| `invoicingStatusRejected` | Rechazado | Rejected |
| `invoicingStatusFailed` | Falló | Failed |
| `invoicingRetry` | Reintentar envío | Retry sending |
| `invoicingCreditNote` | Nota crédito | Credit note |
| `invoicingCreditReason` | Motivo de la nota crédito | Credit note reason |
| `invoicingIssue` | Emitir factura electrónica | Issue electronic invoice |
| `invoicingIssued` | Documento creado: {number} | Document created: {number} |
| `invoicingNotConfigured` | El proveedor de facturación no está configurado; los documentos quedan pendientes. | The invoicing provider is not configured; documents stay pending. |
| `invoicingOnlineOnly` | Requiere conexión | Requires a connection |
| `fiscalCustomerSection` | Datos para factura (opcional) | Invoice details (optional) |
| `fiscalDocType` | Tipo de documento | Document type |
| `fiscalDocNumber` | Número de documento | Document number |
| `fiscalName` | Nombre o razón social | Name or company |
| `fiscalEmail` | Correo electrónico | Email |
| `fiscalInvalidCustomer` | Revisa los datos del cliente | Check the customer details |
| `receiptFiscalPending` | Documento electrónico en proceso | Electronic document in process |
| `notifTypeFiscalFailed` | Documento electrónico con problema | Electronic document problem |
| `notifTypeFiscalResolutionLow` | Resolución de numeración por agotarse | Numbering resolution running out |
| `errorFiscalNotEnabled` | La facturación electrónica no está activa | Electronic invoicing is not enabled |
| `errorFiscalResolutionMissing` | No hay resolución de numeración activa | There is no active numbering resolution |
| `errorFiscalResolutionExpired` | La resolución de numeración venció | The numbering resolution has expired |
| `errorFiscalResolutionExhausted` | Se agotó la numeración autorizada | The authorized numbering is exhausted |
| `errorFiscalSourceNotFound` | No se encontró la venta a facturar | The sale to invoice was not found |
| `errorFiscalSourceNotBillable` | Esta venta no se puede facturar | This sale cannot be invoiced |
| `errorInvalidFiscalCustomer` | Datos del cliente no válidos | Invalid customer details |
| `errorFiscalDocumentNotFound` | Documento no encontrado | Document not found |
| `errorFiscalDocumentNotAccepted` | Solo se puede acreditar un documento aceptado | Only an accepted document can be credited |
| `errorFiscalDocumentAlreadyCredited` | El documento ya tiene una nota crédito | The document already has a credit note |
| `errorInvalidFiscalStatus` | El documento no está en un estado que permita reintentar | The document is not in a retryable state |
| `errorFiscalSettingsIncomplete` | Completa NIT, razón social y municipio | Complete NIT, legal name and municipality |
| `errorFiscalDocumentImmutable` | El documento ya está numerado y no se puede modificar | The document is already numbered and cannot be changed |

### Offline behaviour (AGENTS section 5)

Capturing fiscal data, issuing, retrying, credit notes and every admin screen action require the network; none is queued in the outbox. An offline check-out is queued as today (no fiscal section shown); in `always` mode the sweeper issues the `pos` later; in `on_request` mode the operator issues from the history once online. Money actions (cash intake, shifts) are untouched.

## Security analysis

| Actor | Can |
|---|---|
| `anon` | Nothing (no fiscal function is granted to it). |
| operator | `fiscal_config`, `issue_fiscal_document` (sessions and charges of the active lot), `fiscal_document_for_session` (no customer PII). Cannot read `fiscal_documents`, resolutions, settings; cannot retry or credit. |
| lot admin | Read tables of the active lot; save settings and resolutions; list, retry, credit notes. |
| platform admin | As lot admin through `is_lot_admin`, scoped to the active lot header. |
| service role | `claim_fiscal_documents`, `record_fiscal_result` only. |

- Lot isolation: every table carries `lot_id`; RPCs derive the lot from the source row and compare it with `current_lot_id()`; cron works per row without `current_lot_id()`.
- Integrity: the immutability trigger, `unique (lot_id, doc_type, prefix, number)`, gap-free allocation under a row lock, and absence of delete grants protect the fiscal sequence. Audit: documents themselves are the record; `record_audit` triggers are not attached.
- Secrets: provider token only in the function env; never logged; never reaches the client.
- Privacy: customer name, document number and email are PII; admin-only reads, minimal fields in receipts (no PII printed except what the law requires on an invoice, ASSUMPTION), retention with the document.

## Risks / Trade-offs

- [Tax rate or document type wrong] -> every regulatory choice is data (`fiscal_settings`), isolated in the adapter, and marked ASSUMPTION; `mode = 'off'` default.
- [Provider outage] -> outbox with backoff; receipts say "en proceso"; documents are never lost.
- [DIAN deadline for transmitting after issue] -> the sweeper and dispatcher run every 5 minutes (`JOBS_INTERVAL_SECONDS`); a `pending` document older than a threshold is visible in the admin list (ASSUMPTION: the owner must confirm the legal transmission deadline).
- [Check-out contention on the resolution row] -> issuance is a separate short transaction, not part of `check_out`.
- [Operator forgets the customer data] -> admin credit note + re-issue (decision 7).
- [Rejected number consumed] -> documented assumption; retry reuses the number.

## Migration Plan

1. Implement and merge `add-online-payments` first. Apply the two migrations (additive; `mode = 'off'` everywhere).
2. Add `FISCAL_PROVIDER_*` to `.env`, restart `functions`; validate against the provider's habilitacion (test) environment.
3. Admin enters issuer data and the resolution in `/invoicing`, then switches the lot to `on_request` and finally `always`.
4. Rollback: set `mode = 'off'` (stops creation); documents and numbers remain (never delete).

## Open Questions (owner must answer; each is an ASSUMPTION above)

1. Which document applies to parking sales: documento equivalente electronico POS, factura electronica de venta, or both? Is the buyer "consumidor final" generic data (`222222222222`) correct for POS?
2. Tax: are parking services taxed with IVA at 19 % for this business, or is the issuer "no responsable de IVA" / SIMPLE regime? Are monthly passes taxed the same way?
3. Resolution fields required by the provider (technical key, prefix rules, resolution dates) and who obtains the DIAN numbering authorization (habilitacion first).
4. Which "proveedor tecnologico" will be used and its real API (the generic REST adapter is a placeholder); who provides the test environment credentials.
5. CUFE vs CUDE naming for POS and credit notes, and the QR format (provider-supplied here).
6. DIAN codes: customer document types, payment means, municipality code (DIVIPOLA) and the credit note reason catalogue.
7. Legal deadline for transmitting a document after the sale, retention period (assumed five years) and the privacy notice (Ley 1581) for customer data.
8. Rejected documents: may the same number be re-submitted after correction?
9. Should operators or only admins be allowed to issue invoices with customer data? (This design: both.)
10. Are discounts shown as a document allowance (this design) or must the line price already be discounted?
