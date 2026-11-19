## Context

Neighbouring businesses ("convenios") already get free or discounted parking through the admin-only manual discount of `check_out` (`p_discount_amount` + `p_discount_reason`, stored in `parking_sessions.discount_amount/reason/by/at`; `0011_capacity_discounts.sql`, latest body `0072_billing_integrity.sql`). It has no merchant identity, no caps, no permission model (an admin must be at the desk) and no way to tell a merchant what it owes.

Verified facts this design builds on (open the file before relying on a line number):

- `check_out` latest body is `supabase/migrations/0072_billing_integrity.sql`: 11 parameters, last is `p_cash_received integer default null`; it computes `gross` with `calculate_fare` (or `lost_ticket_amount`), applies the pass (`has_pass` => method `monthly_pass`, discount 0), the admin discount (`AdminRequiredError`, `DiscountReasonRequiredError`, `InvalidDiscountError` when `discount > gross`), attaches the sale to the actor's open shift and stores `amount_charged`. `add-online-payments` (merged before this change) re-declares it with an online settlement step.
- `check_out_preview(p_session_id integer)` latest `0072`; `fare_breakdown(p_category_id, p_entry_time, p_exit_time, p_has_pass default false)` latest `0072` (hours are rounded up ONCE for the whole stay and spread over day/night buckets by largest remainder; the daily tariff caps each calendar day); `calculate_fare` is the `0053` wrapper; `lost_ticket_amount(p_session_id integer, p_exit_time timestamptz)` `0072`.
- `public_session_summary(p_session_id bigint, p_plate text)` `0077` (stable, anon + authenticated; the `public-evidence` Edge Function forwards its JSON untouched as `summary`). `vehicle_history(p_plate text)` latest `0084_vehicle_history_evidence.sql`.
- `record_audit()` (`0031`, reused in `0058`) strips ONLY a column literally named `pin_hash` from `before`/`after`. A column like `token_hash` in an audited table would be written to `audit_log`; therefore credentials live in `merchant_credentials`, which has no audit trigger.
- `pgcrypto` is created in `0001_core_schema.sql` (`create extension if not exists pgcrypto;`). Implementers MUST check where it landed (`select extnamespace::regnamespace from pg_extension where extname = 'pgcrypto'`) and qualify `digest`, `crypt`, `gen_salt`, `gen_random_bytes` accordingly (`public.` or `extensions.`); a test calls the hash helper so a wrong schema fails in CI.
- A `raise exception` rolls back everything the function did, including a counter it just incremented. So a wrong PIN MUST NOT raise: the public RPC returns a JSON status for it (see `merchant_validate`).
- The entry receipt QR payload is the plate (`lib/core/widgets/qr_code.dart`); `plateFromQrPayload` in `lib/core/qr/qr_decoder.dart` accepts a bare plate or `?plate=` / `?p=`. Check-out receipts carry no QR.
- Public pages are listed in `authRedirect` of `lib/app/router/route_access.dart` (`evidencePath`, `policiesPath`, `aboutPath`, `reservePath`); every other path is admin-only unless added to `operatorRoutes`.
- Only `vehicles`, `tariffs`, `categories`, `parking_settings` carry `version` (`0105_row_versions.sql`).

## Goals / Non-Goals

**Goals:**

- A merchant grants a benefit to a parked customer without an app account, and the server applies it at check-out, once, auditable, within caps.
- One function composes the amount owed for every consumer, so the preview, the receipt, the public page and the closing RPC can never drift.
- Two hooks let dynamic pricing and loyalty plug in without re-declaring `fare_quote`, `check_out` or the previews.
- Settlement per merchant for a date range.

**Non-Goals:** see `proposal.md`.

## Decisions

### 1. `fare_quote` is the only place that composes what a session owes

`fare_quote(p_session_id integer, p_exit_time timestamptz, p_discount_amount integer default 0, p_lost_ticket boolean default false) returns jsonb` (NEW, internal, `stable`, `security definer`, `set search_path = public`, `revoke all ... from public, anon, authenticated`; definer functions call it). It does not lock and does not check the caller's lot: its callers (`check_out`, `check_out_preview`, `public_session_summary`) do. `check_out` keeps its 11 arguments: no overload trap (`docs/agent-memory.md`: trailing defaults make old signatures ambiguous).

### 2. A merchant is a link token plus a PIN, not a role

A third `merchant` role would have to be threaded through every lot-scoped RLS policy (`lot_id = current_lot_id()` assumes "authenticated lot member = staff"), `operatorRoutes`, `lot_members` and the admin user screens; a merchant is not staff and a mistake there is a data leak, not a UI bug. The public page `/validate?m=<token>` authenticates with the merchant's private 192-bit token (the link) and a 6-digit PIN, through `security definer` RPCs that never return another merchant's rows, session ids, plates of other vehicles or money. Same family as `/reserve` and `/evidence`. A per-merchant GoTrue login was rejected for the same reason plus password handling by shop cashiers.

### 3. Credentials are separate from the merchant row

`merchants` is audited and readable by every lot member (operators need the picker); `merchant_credentials` has RLS enabled, no policy and no grant. The token is `encode(gen_random_bytes(24), 'hex')` (48 hex chars), shown once, stored as `encode(digest(token, 'sha256'), 'hex')` (high entropy, a fast hash is fine, and it makes the lookup an indexed equality). The PIN is generated by the server (6 digits, never chosen by the admin so it cannot be `123456`), shown once, stored with `crypt(pin, gen_salt('bf', 8))` (low entropy, so a slow salted hash). `merchants.credentials_version` is bumped on every reset so the audit log records "credentials rotated" without any secret.

### 4. A validation is per session, applied at close, terms snapshotted

One row in `merchant_validations` per (merchant, session). The benefit is applied when the session is closed, never while it is open (the customer may still be inside for hours). The merchant's terms are copied into `merchant_validations.terms` at validation time so a later edit of the merchant (or its deletion attempt) cannot change a promise already made, and the settlement bills the snapshot.

### 5. The benefit is one rule per merchant

`free_minutes`, `percentage` or `fixed_amount`, optional `max_amount` per validation. `free_minutes` is computed on the stay (the stay is shortened and re-billed, which is lumpy because billing rounds up to whole hours; see Worked fare examples and open question 1), the other two on the running amount. Exact formulas are in the normative block.

### 6. Hooks for the other two money changes

`fare_quote` calls two NEW functions that are no-ops here and are replaced with `create or replace` (same signature, never an overload) by later changes: `fare_pricing_step` (`add-dynamic-pricing`) and `fare_reward_step` (`add-loyalty-rewards`). Signatures and default bodies are in "RPC signatures". Merchants never read pricing or loyalty tables.

### 7. Settlement is a report, not a balance

`merchant_paid` validations produce an amount owed; `courtesy` ones are a cost of the lot. There is no ledger. Invoicing a merchant is out of scope (`add-electronic-invoicing` invoices customers).

### 8. Merchants are NOT part of the versioned set

They are admin CRUD through RPCs, online only, never queued in the Hive outbox (AGENTS section 5: only operator-critical writes are replayed). They do not get a `version` column or `row_version_guard()`. `parking_settings.merchant_max_per_session` joins the `parking_settings` row, which IS versioned: `set_merchant_policy` bumps `parking_settings.version` automatically; the Flutter `ParkingSettings` entity is NOT extended, so queued offline settings diffs never carry the column and the field-level merge of `0105` (disjoint fields merge silently) handles a concurrent edit.

## Discount interaction (normative)

### Fare composition and discount interaction (NORMATIVE, identical in add-merchant-validations, add-dynamic-pricing and add-loyalty-rewards)

Order of evaluation for one session closed at exit instant E (all amounts are integers in minor units; `R` is the running amount):

1. Base B = `fare_breakdown(...) ->> 'amount'` (tariff, day/night split, daily cap). A monthly-pass holder has B = 0.
2. Exclusions, decided before anything else:
   a. Pass holder (`has_pass`): amount due is 0. No pricing rule, no merchant benefit and no reward is applied, no loyalty visit is counted, validations become `forfeited`, a manual discount is ignored (exactly as today).
   b. Lost ticket: gross = `lost_ticket_amount(...)` unchanged. No pricing rule, no merchant benefit, no reward and no loyalty visit; validations become `forfeited`; the admin manual discount still applies.
3. Gross G = the locked dynamic-pricing rule applied to B (`fare_pricing_step`): `G = B` when the session has no lock. The lock is read from the session, never recomputed at check-out. Pricing is a price change, not a discount: it appears as `pricing`, not as an adjustment line, and `gross_amount` stores G.
4. R = G. Merchant benefits next, one line per `pending` validation ordered by `(created_at, id)`; each line is `a = min(benefit(R), R)`, then `R = R - a`. At most `parking_settings.merchant_max_per_session` validations exist per session. `free_minutes` is computed on the stay instead of on R: `a = min(G - priced(base_of_shortened_stay), R)` where the shortened stay is `E - free_minutes` (if it is not after the entry the benefit is the whole of R). `percentage` is `(R * pct + 50) / 100` (integer, half up). `fixed_amount` is `fixed`. Every merchant line is then capped by its `max_amount`.
5. Loyalty reward next, at most ONE per session: value computed on R after the merchant lines, `a = min(value(R), R)`. The reward is skipped, and stays `available`, when `a = 0` or when the lot has `loyalty_stack_with_merchant = false` and a merchant line with `a > 0` was applied.
6. Manual admin discount D (`p_discount_amount`) is always last: `D > R` raises `InvalidDiscountError`; `amount_due = R - D`.
7. Every step is clamped so that `R >= 0`; a line with `a = 0` is not stored as an adjustment. Rounding is half up on non-negative integers, at the step where a percentage or multiplier is applied, never on an already rounded intermediate twice.
8. Stored on the session at check-out: `gross_amount = G`, `fare_adjustments` = the ordered merchant and reward lines (`type`, `ref_id`, `label`, `kind`, `amount`), `discount_amount = D`, `amount_charged` as the payment rules below decide.
9. Online payments (`add-online-payments`): `amount_due` above is the `gross` that `online_settlement_amounts` receives; an adjustment that arrives after an online payment never lowers the charge below `online_paid_amount` (no refunds).
10. Electronic invoicing (`add-electronic-invoicing`): the document discount is `greatest(coalesce(gross_amount, amount_charged + discount_amount) - amount_charged, 0)`, so merchant, reward and manual reductions all appear as the allowance and the total always equals what was charged.
11. Anti-abuse and anomaly: a zero charge is "explained" (see `anomaly_zero_charge_excluded`) iff `gross_amount > 0`, `discount_amount = 0` and the sum of `fare_adjustments[].amount` equals `gross_amount`.

## Data model

Migration `<NEXT>_merchants.sql` (idempotent: `if not exists`, `drop ... if exists`):

```sql
alter table public.parking_sessions
    add column if not exists gross_amount integer,
    add column if not exists fare_adjustments jsonb not null default '[]'::jsonb;
alter table public.parking_sessions drop constraint if exists parking_sessions_gross_amount_check;
alter table public.parking_sessions add constraint parking_sessions_gross_amount_check
    check (gross_amount is null or gross_amount >= 0);
alter table public.parking_sessions drop constraint if exists parking_sessions_fare_adjustments_check;
alter table public.parking_sessions add constraint parking_sessions_fare_adjustments_check
    check (jsonb_typeof(fare_adjustments) = 'array');

alter table public.parking_settings
    add column if not exists merchant_max_per_session integer not null default 1;
alter table public.parking_settings drop constraint if exists parking_settings_merchant_max_check;
alter table public.parking_settings add constraint parking_settings_merchant_max_check
    check (merchant_max_per_session between 0 and 5);

create table if not exists public.merchants (
    id                  serial       primary key,
    lot_id              integer      not null references public.parking_lots(id),
    name                varchar(120) not null check (length(btrim(name)) between 2 and 120),
    benefit_kind        text         not null
                        check (benefit_kind in ('free_minutes', 'percentage', 'fixed_amount')),
    benefit_value       integer      not null,
    max_amount          integer      check (max_amount is null or max_amount > 0),
    billing_mode        text         not null default 'merchant_paid'
                        check (billing_mode in ('merchant_paid', 'courtesy')),
    daily_cap           integer      check (daily_cap is null or daily_cap between 1 and 10000),
    monthly_cap         integer      check (monthly_cap is null or monthly_cap between 1 and 100000),
    active              boolean      not null default true,
    credentials_version integer      not null default 1,
    created_at          timestamptz  not null default now(),
    updated_at          timestamptz  not null default now(),
    constraint merchants_lot_name_key unique (lot_id, name),
    constraint merchants_id_lot_key unique (id, lot_id),
    constraint merchants_benefit_check check (
        (benefit_kind = 'free_minutes' and benefit_value between 1 and 1440)
     or (benefit_kind = 'percentage'   and benefit_value between 1 and 100)
     or (benefit_kind = 'fixed_amount' and benefit_value >= 1))
);

create table if not exists public.merchant_credentials (
    merchant_id      integer     primary key references public.merchants(id) on delete cascade,
    token_hash       text        not null unique,
    pin_hash         text        not null,
    pin_failures     integer     not null default 0 check (pin_failures between 0 and 5),
    locked_until     timestamptz,
    token_rotated_at timestamptz not null default now(),
    pin_set_at       timestamptz not null default now(),
    last_used_at     timestamptz
);

create table if not exists public.merchant_validations (
    id            bigserial   primary key,
    lot_id        integer     not null references public.parking_lots(id),
    merchant_id   integer     not null,
    session_id    integer     not null references public.parking_sessions(id) on delete cascade,
    source        text        not null check (source in ('public', 'desk')),
    created_by    integer     references public.users(id),
    status        text        not null default 'pending'
                  check (status in ('pending', 'applied', 'revoked', 'forfeited')),
    terms         jsonb       not null,
    amount        integer     not null default 0 check (amount >= 0),
    created_at    timestamptz not null default now(),
    applied_at    timestamptz,
    revoked_by    integer     references public.users(id),
    revoked_at    timestamptz,
    revoke_reason varchar(200),
    constraint merchant_validations_merchant_lot_fkey
        foreign key (merchant_id, lot_id) references public.merchants (id, lot_id),
    constraint merchant_validations_state_check check (
        (status = 'pending'  and applied_at is null and revoked_at is null)
     or (status in ('applied', 'forfeited') and applied_at is not null)
     or (status = 'revoked'  and revoked_at is not null and revoke_reason is not null)),
    constraint merchant_validations_source_check check ((source = 'desk') = (created_by is not null))
);
create unique index if not exists uq_merchant_validation_active
    on public.merchant_validations (merchant_id, session_id) where status <> 'revoked';
create index if not exists ix_merchant_validations_lot_created
    on public.merchant_validations (lot_id, created_at);
create index if not exists ix_merchant_validations_merchant_created
    on public.merchant_validations (merchant_id, created_at);
create index if not exists ix_merchant_validations_pending
    on public.merchant_validations (session_id) where status = 'pending';

alter table public.merchants enable row level security;
alter table public.merchant_credentials enable row level security;  -- no policy, no grant
alter table public.merchant_validations enable row level security;
revoke all on public.merchants, public.merchant_credentials, public.merchant_validations
    from anon, authenticated;
grant select on public.merchants, public.merchant_validations to authenticated;

drop policy if exists merchants_read on public.merchants;
create policy merchants_read on public.merchants
    for select to authenticated using (lot_id = public.current_lot_id());
drop policy if exists merchant_validations_read on public.merchant_validations;
create policy merchant_validations_read on public.merchant_validations
    for select to authenticated using (lot_id = public.current_lot_id());

drop trigger if exists trg_audit_row on public.merchants;
create trigger trg_audit_row after insert or update or delete on public.merchants
    for each row execute function public.record_audit();
drop trigger if exists trg_audit_row on public.merchant_validations;
create trigger trg_audit_row after insert or update or delete on public.merchant_validations
    for each row execute function public.record_audit();
```

`supabase/tests/rpc_test.sql` already asserts that RLS is enabled on every public table; all three tables comply. Anon has no grant, so a `select` from anon fails with `insufficient_privilege` (a test asserts it). Writes happen only inside the security-definer functions below. No FK from `merchant_validations` to the session's lot exists (`parking_sessions` has no `unique (id, lot_id)`); `create_merchant_validation` takes the lot from the merchant and refuses a session of another lot (`SessionNotFoundError`).

`terms` shape (snapshot): `{"merchant_name": text, "benefit_kind": text, "benefit_value": int, "max_amount": int|null, "billing_mode": "merchant_paid"|"courtesy"}`.

`parking_sessions.fare_adjustments` shape: an array of lines `{"type": "merchant"|"reward", "ref_id": int, "label": text, "kind": text, "amount": int}`; a merchant line has `ref_id = merchant_validations.id`, `label = terms.merchant_name`, `kind = terms.benefit_kind`.

## RPC signatures

All `language plpgsql`, `security definer`, `set search_path = public`. Typed errors are `raise exception '<Name>Error'` (PostgREST message = name, mapped by `mapSupabaseError` through SQLSTATE `P0001`). New names only, except the four re-declared functions whose signatures stay identical.

| Function | Grants | Notes |
|---|---|---|
| `list_merchants() returns jsonb` (stable) | authenticated | `require_lot_admin()`; array ordered by name |
| `list_active_merchants() returns jsonb` (stable) | authenticated | `require_app_user()`; lot = `current_lot_id()`; only `active` |
| `save_merchant(p_name text, p_benefit_kind text, p_benefit_value integer, p_max_amount integer, p_billing_mode text, p_daily_cap integer, p_monthly_cap integer, p_active boolean, p_id integer default null) returns jsonb` | authenticated | `require_lot_admin()`; full replacement of the editable fields; create (null id) also creates credentials and returns them once |
| `reset_merchant_credentials(p_merchant_id integer, p_rotate_token boolean default false) returns jsonb` | authenticated | `require_lot_admin()`; new PIN always, new token when `p_rotate_token`; returns them once |
| `delete_merchant(p_id integer) returns jsonb` | authenticated | `require_lot_admin()`; refuses when any validation references it |
| `set_merchant_policy(p_max_per_session integer) returns jsonb` | authenticated | `require_lot_admin()`; 0..5 else `InvalidDataError`; returns `{"max_per_session": int}` |
| `add_merchant_validation(p_merchant_id integer, p_session_id integer) returns jsonb` | authenticated | desk path, `require_app_user()`; session lot must equal `current_lot_id()` |
| `revoke_merchant_validation(p_id bigint, p_reason text) returns jsonb` | authenticated | `require_lot_admin()` |
| `merchant_portal(p_token text) returns jsonb` (stable) | anon, authenticated | `null` for an unknown token |
| `merchant_validate(p_token text, p_pin text, p_plate text) returns jsonb` | anon, authenticated | public page |
| `report_merchant_settlement(p_start_date date, p_end_date date) returns jsonb` (stable) | authenticated | `require_admin()` like `report_revenue` |
| `create_merchant_validation(p_merchant_id integer, p_session_id integer, p_source text, p_actor integer) returns jsonb` | none | internal, shared by desk and public |
| `merchant_hash_token(p_token text) returns text` (immutable) | none | `encode(digest(p_token, 'sha256'), 'hex')` |
| `fare_quote(p_session_id integer, p_exit_time timestamptz, p_discount_amount integer default 0, p_lost_ticket boolean default false) returns jsonb` (stable) | none | internal |
| `fare_pricing_step(p_session_id integer, p_base integer) returns jsonb` (stable) | none | hook, default `jsonb_build_object('amount', p_base, 'pricing', null)` |
| `fare_reward_step(p_session_id integer, p_running integer, p_merchant_total integer) returns jsonb` (stable) | none | hook, default `jsonb_build_object('amount', 0, 'line', null, 'info', null)` |

Revoke pattern for internal functions: `revoke all on function ... from public, anon, authenticated;` (Supabase default privileges grant new functions to `anon`, so the revoke must name it). Public functions: `revoke all ... from public; grant execute ... to anon, authenticated;`.

### Return shapes

`save_merchant` / `list_merchants` merchant object: `{"id": int, "name": text, "benefit_kind": text, "benefit_value": int, "max_amount": int|null, "billing_mode": text, "daily_cap": int|null, "monthly_cap": int|null, "active": bool, "used_today": int, "used_month": int, "pending_now": int, "locked": bool, "credentials_version": int, "created_at": timestamptz}`. `used_today` / `used_month` count non-revoked validations created in the lot's business day / month; `pending_now` counts `pending` ones; `locked` is `locked_until > now()`. `save_merchant` on create returns `{"merchant": {...}, "credentials": {"token": text, "pin": text, "link_path": "/validate?m=<token>"}}`; on update `{"merchant": {...}, "credentials": null}`.

`reset_merchant_credentials`: `{"merchant_id": int, "pin": text, "token": text|null, "link_path": text|null, "credentials_version": int}` (`token`/`link_path` null when `p_rotate_token` is false: the old token is unrecoverable by design).

`list_active_merchants`: `[{"id": int, "name": text, "benefit_kind": text, "benefit_value": int, "max_amount": int|null}]`.

`add_merchant_validation`: `{"validation_id": bigint, "merchant_id": int, "merchant_name": text, "status": "pending", "quote": <fare_quote result at now()>}`.

`revoke_merchant_validation`: `{"id": bigint, "status": "revoked"}`.

`merchant_portal`: `{"merchant_name": text, "benefit_kind": text, "benefit_value": int, "max_amount": int|null, "lot_name": text, "locked_until": timestamptz|null}`; `null` when the token matches no ACTIVE merchant.

`merchant_validate`: one of
- `{"status": "registered", "merchant_name": text, "benefit_kind": text, "benefit_value": int, "max_amount": int|null}`;
- `{"status": "invalid_pin", "attempts_left": int}` (a wrong PIN is NOT an exception, see Context);
- `{"status": "locked", "locked_until": timestamptz}`.
It never returns session ids, plates or amounts.

`report_merchant_settlement`: `{"from": date, "to": date, "merchants": [{"merchant_id": int, "name": text, "billing_mode": text, "benefit_kind": text, "validations": int, "applied": int, "forfeited": int, "revoked": int, "pending_now": int, "discounted_amount": int, "amount_owed": int, "courtesy_amount": int}], "totals": {"validations": int, "applied": int, "forfeited": int, "revoked": int, "discounted_amount": int, "amount_owed": int, "courtesy_amount": int}}`. Basis (documented so nobody mixes them): `validations` counts rows created in the range; `applied`, `forfeited`, `discounted_amount`, `amount_owed`, `courtesy_amount` use `applied_at` in the range (the money is realised when the session closes); `revoked` uses `revoked_at`; `pending_now` ignores the range. Ranges are business days of the lot (`parking_settings.business_timezone`, default `America/Bogota`): `[p_start_date 00:00, p_end_date + 1 day 00:00)`. `amount_owed` sums `amount` of `applied` rows whose `terms.billing_mode = 'merchant_paid'`; `courtesy_amount` the `courtesy` ones. Merchants of the lot with no activity still appear with zeros.

`fare_quote`: exactly the shared contract: `{"session_id": int, "exit_time": timestamptz, "has_pass": bool, "lost_ticket": bool, "base_amount": int, "pricing": object|null, "gross": int, "adjustments": [line], "adjustments_total": int, "discount_amount": int, "amount_due": int, "reward": object|null}`. `has_pass` is the EFFECTIVE flag (false when `p_lost_ticket`, like `check_out` today).

### Typed errors (new unless marked existing)

`MerchantNotFoundError`, `MerchantInactiveError`, `DuplicateMerchantError`, `MerchantInUseError`, `AlreadyValidatedError`, `MerchantLimitError`, `MerchantCapError`, `SessionNotEligibleError` (the session holds an active monthly pass), `ValidationNotFoundError`, `ValidationNotRevocableError`, `RevokeReasonRequiredError` (reason shorter than 3 or longer than 200 characters after trim). Existing and reused: `SessionNotFoundError`, `InvalidPlateError`, `InvalidDiscountError`, `InvalidDataError`, `InvalidReportRangeError`, `LotRequiredError`, `AdminRequiredError`, `InvalidTokenError`, `VehicleNotFoundError`.

### Function algorithms (normative steps)

**`save_merchant`**: (1) `lot := require_lot_admin()`; (2) trim name, 2..120 else `InvalidDataError`; kind in the three values, value range per kind (`free_minutes` 1..1440, `percentage` 1..100, `fixed_amount` >= 1), `p_max_amount` null or > 0, `p_billing_mode` in the two values, caps null or in range, else `InvalidDataError`; (3) update: row must exist in `lot` else `MerchantNotFoundError`; (4) name unique per lot else `DuplicateMerchantError` (catch `unique_violation` on `merchants_lot_name_key`); (5) create: insert, then credentials as in `reset_merchant_credentials` with `p_rotate_token = true`; (6) update sets `updated_at = now()`; benefit edits never touch existing validations (terms are snapshots); (7) return the shape above.

**`reset_merchant_credentials`**: (1) `lot := require_lot_admin()`; merchant in `lot` else `MerchantNotFoundError`; (2) PIN: 6 digits from `gen_random_bytes(4)` modulo 1,000,000, left-padded; (3) token: when `p_rotate_token` or no credentials row exists, `encode(gen_random_bytes(24), 'hex')`; (4) upsert `merchant_credentials` (`pin_hash = crypt(pin, gen_salt('bf', 8))`, `pin_failures = 0`, `locked_until = null`, `pin_set_at = now()`, plus `token_hash` / `token_rotated_at` when rotated); (5) `update merchants set credentials_version = credentials_version + 1, updated_at = now()` (the audit trigger records it); (6) return the shape above.

**`delete_merchant`**: `require_lot_admin()`; row in lot else `MerchantNotFoundError`; any `merchant_validations` row (any status) => `MerchantInUseError` (the admin deactivates instead); else delete (credentials cascade).

**`create_merchant_validation(p_merchant_id, p_session_id, p_source, p_actor)`** (internal): (1) `pg_advisory_xact_lock(hashtext('merchant_validation'), p_merchant_id)` serialises the caps; (2) merchant row else `MerchantNotFoundError`; `not active` => `MerchantInactiveError`; (3) session `for share`: must exist, `status = 'open'` and `lot_id = merchant.lot_id` else `SessionNotFoundError`; (4) the vehicle holds an active monthly pass today (same predicate as `check_out`, business timezone) => `SessionNotEligibleError`; (5) duplicate: a non-revoked validation of this merchant on this session => `AlreadyValidatedError`; (6) per session: count of non-revoked validations of the session `>= parking_settings.merchant_max_per_session` of the lot => `MerchantLimitError` (value 0 therefore refuses everything); (7) caps: count non-revoked validations of the merchant with `created_at` inside the current business day (resp. month) in the lot timezone; `daily_cap` / `monthly_cap` not null and count `>=` cap => `MerchantCapError`; (8) insert (`source`, `created_by = p_actor`, `terms` snapshot); (9) return `{validation_id, merchant_id, merchant_name, status}`.

**`add_merchant_validation`**: `actor := require_app_user()`; session by id: not found or lot `<>` `current_lot_id()` => `SessionNotFoundError` / `LotRequiredError` (same order as `check_out`: not found first, then lot); merchant must belong to the same lot (`MerchantNotFoundError`); calls `create_merchant_validation(..., 'desk', actor)`; attaches `quote := fare_quote(p_session_id, now(), 0, false)`.

**`revoke_merchant_validation`**: `require_lot_admin()`; row in lot else `ValidationNotFoundError`; reason trimmed 3..200 else `RevokeReasonRequiredError`; `status <> 'pending'` or the session is not `open` => `ValidationNotRevocableError`; update `status = 'revoked'`, `revoked_by = current_app_user_id()`, `revoked_at = now()`, `revoke_reason`.

**`merchant_portal`**: trim the token; lookup by `merchant_hash_token`; join `merchants` and `parking_lots`; unknown or inactive => `null`; return the shape (no counters).

**`merchant_validate`**: (1) token trimmed and hashed; no active merchant => raise `MerchantNotFoundError` (unknown, rotated and inactive tokens are indistinguishable; an inactive merchant answers the same, so a token holder cannot probe state); (2) `pg_advisory_xact_lock(hashtext('merchant_pin'), merchant_id)`; (3) credentials row `for update`; `locked_until > now()` => return `{"status": "locked", ...}`; (4) PIN check: `p_pin ~ '^[0-9]{6}$' and crypt(p_pin, pin_hash) = pin_hash`; wrong => `pin_failures + 1`; at 5 set `locked_until = now() + interval '15 minutes'`, `pin_failures = 0` and return `locked`, else return `invalid_pin` with `attempts_left = 5 - pin_failures`; (5) correct => `pin_failures = 0`, `last_used_at = now()`; (6) plate: `upper(regexp_replace(coalesce(p_plate,''), '\s', '', 'g'))` must match `^[A-Z0-9-]{3,20}$` else `InvalidPlateError`; (7) the OPEN session in the merchant's lot of the vehicle with that normalised plate, else `SessionNotFoundError` (a plate of another lot is indistinguishable from an absent plate); (8) `create_merchant_validation(merchant_id, session_id, 'public', null)`; (9) return `registered`.

**`fare_quote`** (the heart; steps map 1:1 to the normative block):

1. Load the session (`SessionNotFoundError`), its vehicle, category and lot timezone. `E := p_exit_time`.
2. `has_pass`: the monthly-pass predicate of `check_out` at `E` in the lot timezone; effective `has_pass := has_pass and not p_lost_ticket`.
3. Branch. Pass: `base 0`, `gross 0`, no pricing, no lines, `discount_amount 0`, `amount_due 0`. Lost ticket: `base := lost_ticket_amount(session, E)`, `gross := base`, no pricing, no lines. Otherwise `base := (fare_breakdown(category, entry_time, E, false) ->> 'amount')::integer`, `step := fare_pricing_step(session.id, base)`, `gross := (step ->> 'amount')::integer`, `pricing := step -> 'pricing'`.
4. Merchant lines, only in the normal branch: for each `pending` validation of the session ordered by `(created_at, id)`: `free_minutes`: shortened exit `E - benefit_value * interval '1 minute'`; if it is `<= entry_time` then `raw := R` else `raw := gross - (fare_pricing_step(session.id, (fare_breakdown(category, entry_time, shortened, false) ->> 'amount')::integer) ->> 'amount')::integer`; `percentage`: `raw := (R::bigint * benefit_value + 50) / 100`; `fixed_amount`: `raw := benefit_value`. Then `a := least(raw, coalesce(max_amount, raw), R)` and clamp at 0; `R := R - a`; append the line when `a > 0`.
5. Reward: `reward_step := fare_reward_step(session.id, R, merchants_total)`; `R := R - least(amount, R)`; append its `line` when not null; `reward := reward_step -> 'info'`. Only in the normal branch.
6. `D := greatest(coalesce(p_discount_amount, 0), 0)` (0 in the pass branch); `D > R` => `InvalidDiscountError`; `amount_due := R - D`.
7. Return the shape. The function never writes.

### Re-declared functions (same signatures; diff the new body against the previous migration, never against a clone)

Precondition (task 0): `add-online-payments` is merged (`grep -l online_settlement_amounts supabase/migrations/*.sql`). Otherwise stop.

**`check_out`** (11 arguments, same order and names): keep everything of the online-payments body except the gross/discount block, which becomes: after `has_pass` / `lost` are known and before the discount checks, `quote := public.fare_quote(session.id, exit_at, discount, lost)`; `has_pass := (quote ->> 'has_pass')::boolean`; the existing pass override (`method := 'monthly_pass'; discount := 0`) stays; the admin / reason checks stay and still run before the quote's `InvalidDiscountError` can surprise a non-admin (so the quote call happens AFTER the `AdminRequiredError` and `DiscountReasonRequiredError` checks; compute the discount checks first, then call `fare_quote` with the already validated `discount`). The online-payments `gross` variable becomes `(quote ->> 'gross')::integer - (quote ->> 'adjustments_total')::integer` (the running amount before the manual discount); the online settlement and the discount step then run exactly as that change wrote them (`amount := greatest(gross - discount, 0)`, desk part, cash checks). After the `update parking_sessions` add `gross_amount = (quote ->> 'gross')::integer` and `fare_adjustments = quote -> 'adjustments'` to the SET list. Then, in the same transaction: mark each pending validation of the session whose `id` appears as `ref_id` of a `merchant` line `applied` with `amount` and `applied_at = now()`; mark every other pending validation of the session `forfeited` (`amount 0`, `applied_at = now()`). The response JSON keeps every existing key and adds `gross_amount`, `fare_adjustments` and `pricing` (`quote -> 'pricing'`, null until `add-dynamic-pricing`); `discount_amount` stays the MANUAL discount only. `check_out` still raises `SessionAlreadyClosedError` before any of this for a closed session, so the loop never runs twice.

**`check_out_preview(p_session_id integer)`**: keep the body of the online-payments version; after `breakdown` is computed add `quote := public.fare_quote(session.id, preview_at, 0, false)` and return the existing keys plus `'quote', quote`, `'gross', quote.gross`, `'adjustments', quote.adjustments`, `'adjustments_total', quote.adjustments_total`. Key semantics: `amount` stays "fare right now" and now means the GROSS (after pricing, before benefits); `quote.amount_due` is the amount after benefits. The top-level `amount_due` key is defined by `add-online-payments` as the desk balance: it MUST be computed as `online_settlement_amounts(quote.gross - quote.adjustments_total, online_paid_amount, online_paid_at, preview_at, grace).desk_due`; when that change is not merged it equals `quote.amount_due`. `lost_ticket_amount` stays as is (a lost ticket has no automatic adjustments).

**`public_session_summary(p_session_id bigint, p_plate text)`**: unchanged checks; for an `open` session add `quote := fare_quote(row.id, exit_at, 0, false)`, `amount := quote.amount_due`; for a `closed` session `amount` stays `coalesce(row.amount_charged, ...)`. Add keys `gross` (closed: `coalesce(row.gross_amount, amount)`), `adjustments` (closed: `row.fare_adjustments`), `pricing` (null until `add-dynamic-pricing`, which adds it from the quote or the session lock) and `quote` for open sessions. `breakdown` stays. Keep `revoke all ... from public; grant execute ... to anon, authenticated;`.

**`vehicle_history(p_plate text)`**: re-declare the `0084` body and add `'gross_amount', s.gross_amount, 'fare_adjustments', s.fare_adjustments` to the per-session object.

**`anomaly_zero_charge_excluded(p_session_id integer)`** (only when `add-cash-anomaly-detection` is merged: `grep -l anomaly_zero_charge_excluded supabase/migrations/*.sql`): `create or replace` with the same signature and the same revoke from `public, anon, authenticated`:

```sql
create or replace function public.anomaly_zero_charge_excluded(p_session_id integer)
returns boolean language sql stable set search_path = public
as $$
    select exists (
        select 1 from public.parking_sessions s
         where s.id = p_session_id
           and s.gross_amount > 0
           and s.discount_amount = 0
           and coalesce((select sum((l ->> 'amount')::integer)
                           from jsonb_array_elements(s.fare_adjustments) l), 0) = s.gross_amount
    )
$$;
```

This is the registration mechanism for validations AND rewards: any automatic line written into `fare_adjustments` explains a zero charge, so `add-loyalty-rewards` and `add-dynamic-pricing` do NOT redefine it. If the anomaly change is not merged yet, skip this and write a line in `docs/agent-memory.md` (task 2.6).

## State machines

Validation:

```text
          create_merchant_validation
                    |
                    v
   +---------- pending ----------+
   | revoke (admin, session open)|  check_out
   v                             v
 revoked              applied (line amount > 0)  |  forfeited (pass, lost ticket, amount 0, or never produced a line)
```

`applied`, `forfeited` and `revoked` are terminal. Merchant: `active` toggles only through `save_merchant`; credentials: `ok` -> (5 wrong PINs) -> `locked` for 15 minutes -> `ok` (automatically when `locked_until` passes, or by `reset_merchant_credentials`).

## Flutter

NEW shared files:

```text
lib/core/fare/fare_adjustment.dart   # FareAdjustment {FareAdjustmentType type (merchant|reward|unknown), int refId, String label, String kind, int amount}; fromJson; Equatable
lib/core/fare/fare_quote.dart        # FareQuote {int baseAmount, int gross, List<FareAdjustment> adjustments, int adjustmentsTotal, int discountAmount, int amountDue, bool hasPass, bool lostTicket, Map<String, Object?>? pricing, Map<String, Object?>? reward}; FareQuote.fromJson
```

`FareAdjustmentType.parse(String)` maps unknown values to `unknown` (forward compatible with `reward`). `pricing` and `reward` stay raw maps: other changes add typed parsers in their own feature and never change this constructor.

NEW feature:

```text
lib/features/merchants/
  domain/entities/merchant.dart                 # Merchant, MerchantBenefitKind, MerchantBillingMode, MerchantCredentials
  domain/entities/merchant_portal.dart          # MerchantPortal (public identity + benefit)
  domain/entities/merchant_validation_result.dart  # sealed: ValidationRegistered, ValidationInvalidPin, ValidationLocked
  domain/entities/merchant_settlement.dart      # MerchantSettlement, MerchantSettlementRow
  domain/repositories/merchant_repository.dart          # admin + desk port
  domain/repositories/public_merchant_repository.dart   # anonymous port
  application/merchants_cubit.dart              # admin list
  application/merchant_validation_cubit.dart    # public page
  application/merchant_settlement_cubit.dart
  infrastructure/merchant_remote_data_source.dart
  infrastructure/merchant_repository_impl.dart
  infrastructure/public_merchant_remote_data_source.dart
  infrastructure/public_merchant_repository_impl.dart
  presentation/merchants_page.dart              # list + policy + settlement tab
  presentation/merchant_form_dialog.dart
  presentation/merchant_credentials_dialog.dart # show-once token/PIN/link
  presentation/merchant_settlement_section.dart
  presentation/merchant_settlement_csv.dart     # merchantSettlementCsv(...)
  presentation/merchant_settlement_pdf.dart     # buildMerchantSettlementPdf(...)
  presentation/public_validation_page.dart
  presentation/desk_merchant_section.dart       # picker used by the check-out dialog
lib/app/di/modules/merchants_module.dart
lib/app/router/deferred/merchants_entry.dart
```

Entities (Equatable; `fromJson(Map<String, dynamic>)` on the entity like `PublicReservation.fromJson`):

- `enum MerchantBenefitKind { freeMinutes, percentage, fixedAmount }` with `static parse(String)` (wire values `free_minutes`, `percentage`, `fixed_amount`); `enum MerchantBillingMode { merchantPaid, courtesy }`.
- `Merchant {int id, String name, MerchantBenefitKind kind, int value, int? maxAmount, MerchantBillingMode billingMode, int? dailyCap, int? monthlyCap, bool active, int usedToday, int usedMonth, int pendingNow, bool locked, int credentialsVersion}`.
- `MerchantCredentials {int merchantId, String pin, String? token, String? linkPath}` with `Uri? linkFor(Uri? appBase)`.
- `MerchantPortal {String merchantName, MerchantBenefitKind kind, int value, int? maxAmount, String lotName, DateTime? lockedUntil}`.
- `sealed class MerchantValidationResult`: `ValidationRegistered(MerchantPortal summary)`, `ValidationInvalidPin(int attemptsLeft)`, `ValidationLocked(DateTime until)`.
- `MerchantSettlement {DateTime from, DateTime to, List<MerchantSettlementRow> rows, MerchantSettlementRow totals}`; `MerchantSettlementRow {int? merchantId, String name, MerchantBillingMode? billingMode, int validations, int applied, int forfeited, int revoked, int pendingNow, int discountedAmount, int amountOwed, int courtesyAmount}`.

Ports:

```dart
abstract class MerchantRepository {                 // authenticated
  Future<List<Merchant>> list();                    // admin, list_merchants
  Future<List<Merchant>> listActive();              // desk, list_active_merchants
  Future<({Merchant merchant, MerchantCredentials? credentials})> save(MerchantDraft draft);
  Future<MerchantCredentials> resetCredentials(int merchantId, {bool rotateToken});
  Future<void> delete(int merchantId);
  Future<int> loadPolicy();                          // select merchant_max_per_session (RLS: own lot)
  Future<int> savePolicy(int maxPerSession);
  Future<FareQuote> addValidation({required int merchantId, required int sessionId});
  Future<void> revokeValidation({required int validationId, required String reason});
  Future<MerchantSettlement> settlement({required DateTime start, required DateTime end});
}
abstract class PublicMerchantRepository {           // anonymous
  Future<MerchantPortal?> portal(String token);
  Future<MerchantValidationResult> validate({required String token, required String pin, required String plate});
}
```

`MerchantDraft` is a plain value object (`id?`, `name`, `kind`, `value`, `maxAmount?`, `billingMode`, `dailyCap?`, `monthlyCap?`, `active`); `save` calls `save_merchant` with `p_*` names. Data sources call RPCs by name and wrap each call in `try { ... } catch (error) { throw mapSupabaseError(error); }`. `validate` maps the JSON `status` to the sealed result and lets typed exceptions (`SessionNotFoundError`, `AlreadyValidatedError`, ...) surface as `ValidationFailure(code)`. Nothing here uses `SyncOutbox`, `MutationEntity` or Hive.

Cubits (extend `ResilientCubit` from `lib/core/state/resilient_cubit.dart`, sealed `Equatable` states; the four UI states):

- `MerchantsCubit` (admin): `MerchantsInitial`, `MerchantsLoading` (skeleton rows), `MerchantsLoaded(List<Merchant> merchants, int maxPerSession, {Submission submission, MerchantCredentials? justCreated})` (an empty list renders the empty state with the "New agreement" call to action), `MerchantsFailure(Failure failure)` (retry). Methods: `load()`, `save(MerchantDraft)`, `resetCredentials(int id, {bool rotateToken})`, `delete(int id)`, `savePolicy(int)`; actions reuse `Submission` from `lib/core/state/submission.dart`; `justCreated` is cleared by `dismissCredentials()`.
- `MerchantValidationCubit` (public page): `MerchantValidationLoading`, `MerchantValidationReady(MerchantPortal portal, {bool submitting, int? attemptsLeft, DateTime? lockedUntil, Failure? actionFailure})` (form), `MerchantValidationDone(MerchantPortal portal)` (success with "validate another plate"), `MerchantValidationInvalidLink` (empty state: unknown token), `MerchantValidationFailure(Failure failure)` (network error, retry). Methods: `load(String token)`, `submit({required String pin, required String plate})`, `another()`. The cubit keeps the PIN only in memory for the page session and clears it on `Done`.
- `MerchantSettlementCubit`: `MerchantSettlementLoading`, `MerchantSettlementLoaded(MerchantSettlement settlement)` (empty rows render the empty state), `MerchantSettlementFailure(Failure)`; `load({required DateTime start, required DateTime end})`.

Presentation notes: the admin page is `Scaffold` + `AppBar` with the two export actions (`AppIconButton`, `actionExportPdf`, `reportsExportCsv` keys already exist) shown on the settlement tab; widgets reused by name: `SectionHeader`, `EmptyState`, `ErrorState`, `StatusChip`, `SkeletonList`, `AppIconButton`, `ConfirmDialog`, `PlateText`, `PlateInputField`, `FilterBar`, `MetricCard`; PDF through `PdfDocumentBuilder` (`lib/core/receipt/pdf_table.dart`) and `sharePdfBytes` / `pdfFileName('liquidacion', start, end)` (`lib/core/receipt/pdf_share.dart`); CSV is raw integers (`section,label,value` rows like `reportCsv`) copied to the clipboard like the revenue report. No colours outside `Theme.of(context)`; every target at least `Layout.minTouch`. All money through `Money` / `CopFormatter` / `Formatters.money`.

Public page: `PublicValidationPage({required String? token, QrDecoder? qrDecoder, PlateImageCapture? capture})` shows the merchant name and benefit copy, a `PlateInputField`, a camera/QR button (phone: `scanQrWithCamera` from `lib/core/qr/qr_scan_page.dart`; web: `PlateImageCapture` + `QrDecoder`, then `plateFromQrPayload`; hidden when neither is injected, exactly like `CheckOutPage`), a 6-digit PIN field (obscured, numeric keypad, no autofill) and the result banner. After `Done` it offers "Validate another plate". The page never prints plates or amounts it did not just type.

Desk integration (check-out): `showCheckoutDialog` gets an optional `MerchantDeskOptions? merchants` parameter: `{List<Merchant> options, Future<CheckOutPreview> Function(int merchantId) apply, Future<CheckOutPreview> Function(int validationId, String reason)? revoke}`. The dialog renders a collapsed "Convenio" section only when online, `options` is not empty, the session is not a pass holder and "lost ticket" is off; selecting a merchant and pressing "Aplicar convenio" calls `apply`, which replaces the dialog's preview (state) with the returned one; each merchant line of `preview.quote.adjustments` shows a remove icon for admins (`revoke`, asks a reason of 3..200 characters). `CheckOutPage` builds the options from `serviceLocator<MerchantRepository>().listActive()` guarded by `serviceLocator.isRegistered<MerchantRepository>()` and a `NetworkFailure` simply hides the section. `apply` is `merchantRepo.addValidation(...)` followed by `checkOutRepo.preview(sessionId)`.

Other edits (all additive):

- `CheckOutPreview` (`lib/features/check_out/domain/entities/check_out_preview.dart`): add `FareQuote? quote`, `int? amountDue` (absent key => `quote?.amountDue ?? amount`); `fromJson` reads `quote` and `amount_due`; add both to `props`.
- `FareBreakdownView` (`.../widgets/fare_breakdown_view.dart`): after the hour lines, one row per `quote.adjustments` (label via `fareAdjustmentMerchant`, value `-Formatters.money(amount)`) and a final "a pagar" row from `preview.amountDue`.
- `CheckOutReceipt` + `CheckOutReceiptDto` (`.../models/check_out_receipt_dto.dart`, regenerate `.g.dart` with `build_runner`): add `int? grossAmount`, `List<FareAdjustment> adjustments` (default empty).
- `ReceiptData` (`lib/core/receipt/receipt_data.dart`): add `int? grossAmount` and `List<FareAdjustment> adjustments = const []`; `ReceiptCard` (`lib/core/widgets/receipt_card.dart`), `EscPosGenerator` and `SystemDialogReceiptPrinter` print, between the entry/exit lines and the total, `labels.gross` then one `labels.benefit + ' ' + label` row per adjustment as `-$X`, only for a settled check-out (`isCheckOut && !pendingSync`). `ReceiptLabels` (`lib/core/receipt/receipt_labels.dart`) gains `gross` and `benefit` in both `spanish` and `english` constants (Spanish `Tarifa` / `Convenio`, English `Fare` / `Agreement`); the 400 px layout must not overflow.
- `VehicleHistorySession` (`lib/features/vehicle_history/domain/entities/vehicle_history.dart`): `int? grossAmount`, `List<FareAdjustment> adjustments`; `_receipt` in `vehicle_history_page.dart` passes them.
- `PublicSessionSummary` (`lib/features/evidence/domain/entities/public_evidence.dart`): `int? gross`, `List<FareAdjustment> adjustments`; `public_evidence_page.dart` lists the lines under the amount.
- Router: `validatePath = '/validate'` constant in `lib/app/router/route_access.dart` and added to the public list of `authRedirect`; `GoRoute(path: validatePath)` in `lib/app/router/app_router.dart` next to `reservePath`, providing `MerchantValidationCubit` and reading `state.uri.queryParameters['m']`; `/merchants` deferred (`merchants_entry.dart`, admin-only by default, NOT added to `operatorRoutes`); `AppDestination('/merchants', _merchants, Icons.storefront_outlined, Icons.storefront)` appended to `managementDestinations` in `lib/app/shell/app_destinations.dart` with a `navMerchants` label.
- DI: `registerMerchantsModule(GetIt sl)` in `lib/app/di/modules/merchants_module.dart` registers `MerchantRemoteDataSource` and `PublicMerchantRemoteDataSource` (lazy singletons over `sl<SupabaseClient>()`), both repositories (lazy singletons), `MerchantsCubit`, `MerchantValidationCubit` and `MerchantSettlementCubit` (factories); call it in `lib/app/di/injection.dart` beside `registerPublicBookingModule`.
- `lib/core/l10n/failure_messages.dart` `_byCode`: every new typed name below.

## l10n (add to both ARB files, regenerate with `flutter gen-l10n`)

Follow the placeholder style of the existing waitlist keys. Both files get every key.

| Key | ES | EN |
|---|---|---|
| `navMerchants` | Convenios | Agreements |
| `merchantsTitle` | Convenios con comercios | Merchant agreements |
| `merchantsEmpty` | Aún no hay convenios. Crea uno para dar descuento a los clientes de un comercio vecino. | No agreements yet. Create one to give a neighbouring business's customers a discount. |
| `merchantsAdd` | Nuevo convenio | New agreement |
| `merchantFormName` | Nombre del comercio | Business name |
| `merchantFormKind` | Tipo de beneficio | Benefit type |
| `merchantKindFreeMinutes` | Minutos gratis | Free minutes |
| `merchantKindPercentage` | Porcentaje | Percentage |
| `merchantKindFixedAmount` | Monto fijo | Fixed amount |
| `merchantFormValueMinutes` | Minutos gratis (1-1440) | Free minutes (1-1440) |
| `merchantFormValuePercent` | Porcentaje (1-100) | Percentage (1-100) |
| `merchantFormValueAmount` | Monto del descuento | Discount amount |
| `merchantFormMaxAmount` | Tope por validación (opcional) | Cap per validation (optional) |
| `merchantFormBilling` | ¿Quién paga el beneficio? | Who pays for the benefit? |
| `merchantBillingMerchantPaid` | El comercio paga | The merchant pays |
| `merchantBillingCourtesy` | Cortesía del parqueadero | Parking lot courtesy |
| `merchantFormDailyCap` | Máximo por día (opcional) | Daily maximum (optional) |
| `merchantFormMonthlyCap` | Máximo por mes (opcional) | Monthly maximum (optional) |
| `merchantFormActive` | Activo | Active |
| `merchantUsage` | Hoy {today} · Mes {month} | Today {today} · Month {month} |
| `merchantPending` | {count, plural, =0{Sin pendientes} =1{1 pendiente} other{{count} pendientes}} | {count, plural, =0{None pending} =1{1 pending} other{{count} pending}} |
| `merchantLocked` | Bloqueado por PIN | Locked by PIN |
| `merchantCredentialsTitle` | Credenciales del comercio | Merchant credentials |
| `merchantCredentialsHint` | Se muestran una sola vez. Entrega el enlace y el PIN al cajero del comercio. | Shown only once. Give the link and PIN to the merchant's cashier. |
| `merchantCredentialsLink` | Enlace | Link |
| `merchantCredentialsPin` | PIN | PIN |
| `merchantCredentialsCopy` | Copiar | Copy |
| `merchantCredentialsNoAppUrl` | Falta configurar APP_URL: copia solo la ruta {path}. | APP_URL is not configured: copy the path {path} only. |
| `merchantResetPin` | Generar nuevo PIN | Generate new PIN |
| `merchantRotateToken` | Generar nuevo enlace y PIN | Generate new link and PIN |
| `merchantDeleteConfirm` | ¿Eliminar el convenio {name}? | Delete the agreement {name}? |
| `merchantPolicyTitle` | Convenios por vehículo | Agreements per vehicle |
| `merchantPolicyMax` | Máximo de convenios por vehículo (0 = desactivar) | Maximum agreements per vehicle (0 = off) |
| `merchantSettlementTitle` | Liquidación | Settlement |
| `merchantSettlementEmpty` | No hubo convenios en este rango. | No agreements were used in this range. |
| `merchantSettlementValidations` | Validaciones | Validations |
| `merchantSettlementApplied` | Aplicadas | Applied |
| `merchantSettlementForfeited` | Sin efecto | Forfeited |
| `merchantSettlementRevoked` | Revocadas | Revoked |
| `merchantSettlementDiscounted` | Descuento otorgado | Discount granted |
| `merchantSettlementOwed` | A cobrar al comercio | Owed by the merchant |
| `merchantSettlementCourtesy` | Cortesía del parqueadero | Parking lot courtesy |
| `merchantSettlementPdfTitle` | Liquidación de convenios | Agreement settlement |
| `validateTitle` | Validar parqueo | Validate parking |
| `validatePlateLabel` | Placa del cliente | Customer's plate |
| `validateScanQr` | Escanear QR del recibo | Scan the receipt QR |
| `validatePinLabel` | PIN del comercio | Merchant PIN |
| `validateSubmit` | Validar | Validate |
| `validateBenefitMinutes` | {minutes} minutos gratis | {minutes} free minutes |
| `validateBenefitPercent` | {percent}% de descuento | {percent}% discount |
| `validateBenefitAmount` | {amount} de descuento | {amount} discount |
| `validateSuccess` | Convenio registrado: {benefit} | Agreement registered: {benefit} |
| `validateWrongPin` | PIN incorrecto. Intentos restantes: {left} | Wrong PIN. Attempts left: {left} |
| `validateLocked` | Demasiados intentos. Intenta de nuevo a las {time}. | Too many attempts. Try again at {time}. |
| `validateInvalidLink` | Este enlace no es válido. Pide uno nuevo al parqueadero. | This link is not valid. Ask the parking lot for a new one. |
| `validateAnother` | Validar otra placa | Validate another plate |
| `deskMerchantTitle` | Convenio | Agreement |
| `deskMerchantPick` | Elegir comercio | Choose a business |
| `deskMerchantApply` | Aplicar convenio | Apply agreement |
| `deskMerchantRevoke` | Quitar convenio | Remove agreement |
| `deskMerchantRevokeReason` | Motivo (mínimo 3 caracteres) | Reason (at least 3 characters) |
| `deskMerchantOffline` | Requiere conexión | Needs a connection |
| `fareGross` | Tarifa | Fare |
| `fareAdjustmentMerchant` | Convenio {name} | Agreement {name} |
| `fareAmountDue` | A pagar | Amount due |
| `errorMerchantNotFound` | Comercio no encontrado. | Business not found. |
| `errorMerchantInactive` | Este convenio está desactivado. | This agreement is disabled. |
| `errorDuplicateMerchant` | Ya existe un comercio con ese nombre. | A business with that name already exists. |
| `errorMerchantInUse` | El convenio tiene validaciones: desactívalo en lugar de eliminarlo. | The agreement has validations: disable it instead of deleting it. |
| `errorAlreadyValidated` | Este comercio ya validó ese vehículo. | This business already validated that vehicle. |
| `errorMerchantLimit` | El vehículo ya alcanzó el máximo de convenios. | The vehicle reached the maximum number of agreements. |
| `errorMerchantCap` | El comercio alcanzó su límite de validaciones. | The business reached its validation limit. |
| `errorSessionNotEligible` | Este vehículo tiene mensualidad: no necesita convenio. | This vehicle has a monthly pass: it does not need an agreement. |
| `errorValidationNotFound` | Validación no encontrada. | Validation not found. |
| `errorValidationNotRevocable` | Solo se puede quitar una validación pendiente de un vehículo que sigue dentro. | Only a pending validation of a vehicle still inside can be removed. |
| `errorRevokeReasonRequired` | Escribe un motivo de 3 a 200 caracteres. | Write a reason of 3 to 200 characters. |

Reuse the existing keys for `SessionNotFoundError`, `InvalidDiscountError`, `InvalidDataError`, `AdminRequiredError`; map `InvalidPlateError` if `failure_messages.dart` does not map it yet (grep first).

## Offline behaviour

Validations (public and desk), the admin screens and the settlement report are online only: a `NetworkFailure` renders the error state with retry, nothing is queued, `MutationEntity`, `PendingMutation` and the Hive adapters are untouched. A queued check-out replays with `client_exit_time`: `check_out` calls `fare_quote(session, exit_at, ...)`, so the base, the free-minutes shortening and the pricing hook all use the exit instant the operator confirmed, never the sync time; the validations that exist when the replay runs are applied (a validation registered between the offline exit and the replay is honoured, because the customer was legitimately still inside when the merchant stamped it). Reward expiry is judged at `now()` by the loyalty hook (see that change). The pending-sync receipt never prints an amount or an adjustment (existing rule: billing math is backend-only), and the desk picker is hidden offline (`deskMerchantOffline` shown instead).

## Security analysis

| Actor | Can | Cannot |
|---|---|---|
| anon without token | nothing (no table grants; `merchant_portal` answers `null`, `merchant_validate` raises `MerchantNotFoundError`) | read any table, call desk, admin, report or internal RPCs |
| anon holding a token (merchant link) | `merchant_portal` (name, benefit); with the PIN, `merchant_validate` for plates with an open session in the merchant's lot | read sessions, plates, amounts, other merchants; change the merchant; validate in another lot; bypass caps |
| authenticated operator | `list_active_merchants`, `add_merchant_validation` in own lot, read `merchants` / `merchant_validations` of own lot | save/reset/delete merchants, revoke (`AdminRequiredError`), settlement, other lots (`LotRequiredError` / `SessionNotFoundError`) |
| lot admin / admin | all of the above + CRUD, credentials, policy, revoke, `report_merchant_settlement` | other lots |
| service_role | n/a | n/a |

- Lot isolation: every definer function takes the lot from the merchant row or `current_lot_id()` and filters explicitly (definer functions bypass RLS); table policies use `current_lot_id()`.
- Secrets: token hash and PIN hash exist only in `merchant_credentials` (no policy, no grant, no audit trigger). The token and PIN are returned exactly once, over TLS, to an admin. `merchant_validate` compares in SQL; no secret is logged (no `raise notice`).
- Brute force: the token has 192 bits (not guessable); the PIN is limited to 5 attempts per 15 minutes per merchant and the counter is committed because wrong PINs return JSON instead of raising. A holder of the token can lock the merchant for 15 minutes by guessing wrong (nuisance, bounded; the admin can reset). There is no per-IP limit in SQL; the gateway rate limit applies.
- Enumeration: unknown, rotated and inactive tokens answer identically; a plate of another lot or without an open session answers `SessionNotFoundError`. A token+PIN holder can therefore learn whether a plate is currently inside the lot (limited by the PIN lock and the audit trail); accepted and listed as open question 6.
- Abuse by a merchant: the validation is per open session, capped per day and month, revocable by an admin while the vehicle is inside, billed to the merchant when `merchant_paid`, and audited with `source = 'public'` and a null actor. Abuse by an operator: the desk path records `created_by`, shows in `audit_log`, and a zero charge it causes is flagged unless explained by the lines.
- Privacy: no personal data of the customer is stored beyond the plate already in `vehicles`; the public RPC never returns it.
- Injection: all inputs are bound parameters; plates are normalised and regex-checked; amounts are integers.

## Worked fare examples

Fixtures (section D of the shared contract; minor units COP, `America/Bogota`): car hourly 3000, nightly 2000 (22:00-06:00), daily 20000, lost ticket fee 15000. `pricing` and `reward` are no-ops unless the other two changes are merged; examples 8 and 9 assume them.

1. Percentage, same day (F1, 09:00 -> 11:30). Base: 3 h x 3000 = 9000. Merchant A 50%: `(9000 * 50 + 50) / 100 = 4500`. R = 4500; `amount_due = 4500`; stored `gross_amount 9000`, one line `{merchant, 4500}`.
2. Free minutes (F1). `free_minutes = 30`: shortened exit 11:00, stay 2 h, 2 billable hours = 6000, benefit `9000 - 6000 = 3000`, `amount_due = 6000`. Same merchant, exit 11:40: base 9000 (2 h 40 -> 3 h), shortened 2 h 10 -> 3 h = 9000, benefit 0: no line, the validation becomes `forfeited` (lumpy, see open question 1).
3. Midnight wrap (F2, 23:00 Mon -> 02:00 Tue, base 6000). Merchant fixed 2500: `a = 2500`, due 3500. With `max_amount 2000`: `a = least(2500, 2000, 6000) = 2000`, due 4000.
4. Daily cap (F3, base 20000, `daily_cap_applied`). Percentage 100: `(20000 * 100 + 50) / 100 = 20000`, due 0, validation `applied` 20000; `gross_amount 20000 > 0`, `discount_amount 0`, sum of lines = 20000: the zero charge is explained. Percentage 50 with `max_amount 8000`: raw 10000 -> 8000, due 12000.
5. Lost ticket (F1 + lost). `gross = greatest(9000, 15000) = 15000`, no pricing, the pending validation is `forfeited`; an admin manual discount of 1000 gives `amount_due = 14000`.
6. Pass holder (F5). `has_pass`: base 0, gross 0, due 0, the validation is refused at creation (`SessionNotEligibleError`); a validation created before the pass started becomes `forfeited` at check-out.
7. Two merchants (`merchant_max_per_session = 2`, F1 base 9000). A fixed 2000 created first, B 50% created second: A `a = 2000`, R 7000; B `(7000 * 50 + 50) / 100 = 3500`, R 3500, due 3500. Created in the opposite order: B `(9000 * 50 + 50) / 100 = 4500`, R 4500; A 2000, due 2500. Oldest first is therefore normative.
8. Canonical stack (needs pricing + loyalty). F1 base 9000; pricing 12000 bps -> `G = 10800` (`gross_amount 10800`); merchant 50% -> `a = 5400`, R 5400; reward fixed 2000 -> `a = 2000`, R 3400; manual discount 400 -> `amount_due = 3000`.
9. Floor (canonical): 1 h stay, base 3000, merchant fixed 5000 -> `a = 3000`, R 0; the reward step receives R 0 and returns no line (reward stays available); `amount_due 0`; the zero charge is explained (lines sum 3000 = gross). Free minutes with pricing (needs pricing): base 9000, multiplier 12000 -> `G = 10800`; 30 free minutes, exit 11:30: shortened base 6000 priced 7200, `a = 10800 - 7200 = 3600`, due 7200.
10. Rounding: R 3333, percentage 15: `(3333 * 15 + 50) / 100 = (49995 + 50) / 100 = 500` (exactly 499.95 rounds to 500).

## Trade-offs and rejected alternatives

- A `merchant` role in GoTrue: rejected (Decision 2).
- Free-text validation codes the cashier types without a PIN: rejected; a leaked code would be reusable and unaccountable.
- A PIN chosen by the admin: rejected (weak PINs); server-generated.
- Raising `MerchantLockedError` on a wrong PIN: rejected because the rollback would erase the attempt counter; the public RPC returns a status instead. (`MerchantLockedError` is therefore NOT a typed error of this change.)
- Hash columns inside `merchants`: rejected because `record_audit` only strips `pin_hash` (it would copy `token_hash` into `audit_log`).
- Computing adjustments in Dart: rejected; the fare must be authoritative on the server (offline replay, reprints, reports).
- Applying the benefit while the session is open: rejected; it is a payment-time decision and would change the public page on every validation.
- Reading the merchant's current terms at check-out instead of the snapshot: rejected; editing a merchant must not rewrite promises or the settlement.
- One column per benefit kind: rejected for `benefit_kind` + `benefit_value` (a check constraint keeps the ranges).
- A balance ledger per merchant: out of scope; the settlement report is the input for whatever invoicing the lot uses.
- Re-declaring `fare_quote` in the other two changes: rejected in favour of two hooks, so the three changes never conflict on the long function.

## Open questions for the owner

1. `free_minutes` is applied by shortening the stay and re-billing, and billing rounds up to whole hours, so 30 free minutes only saves money when the shortened stay crosses an hour boundary (examples 2 and 3 of the free-minutes case). Should the benefit instead be "first N minutes free, then ceil" or a `free_hours` kind?
2. Should a desk validation for a `courtesy` merchant need admin rights (an operator could otherwise grant a cost to the lot)?
3. May a merchant see its own usage (today / month) on the public page after the PIN?
4. Settlement basis: validations by creation date vs money by closing date (as designed). Is a monthly cut-off by closing date enough for the accountant?
5. After a customer already paid online, a later validation cannot lower the charge below the online payment (no refunds). Acceptable, or must the desk refund?
6. A token+PIN holder can probe whether a plate is inside. Is that acceptable for neighbouring shops?
7. Should the merchant link be printable as a QR sticker for the shop counter (needs `APP_URL` configured)?
8. Who delivers the PIN to the merchant (admin screen copy button, WhatsApp, paper)?
