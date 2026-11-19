## Context

Verified against the repository on 2026-11-10 (head migration `0102`; `0103` belongs to `add-public-booking-captcha`):

- `check_out` — latest body `0072_billing_integrity.sql` (11 parameters, last is `p_cash_received integer default null`). It accepts `cash|card|transfer|monthly_pass|exempt` (anything else raises `InvalidPaymentMethod`), computes `gross` with `calculate_fare` (or `lost_ticket_amount`), applies the pass and the admin discount, attaches the sale to the actor's open shift (`for share`) and stores `amount_charged`, `payment_method`, `card_type`, `cash_received`, `cash_change`, `shift_id`, `closed_recorded_at`, `ticket_number`.
- `check_out_preview(p_session_id integer)` — `0072`; returns `fare_breakdown` keys plus `session_id`, `amount`, `has_pass`, `entry_time`, `previewed_at`, `lost_ticket_amount`.
- `public_session_summary(p_session_id bigint, p_plate text)` — `0077`; `anon` + `authenticated`; plate is the key; the `public-evidence` Edge Function calls it with the service key and returns it as `summary`.
- `shift_totals(p_shift_id bigint)` — `0073`; `expected_cash = opening_float + cash_sales + pass_cash_sales + deposits - withdrawals`.
- `report_revenue(date, date)` — latest `0024_lot_scope.sql`; `report_revenue_all(date, date)` — latest `0039_report_lot_comparison.sql`.
- `open_sessions_view` — latest `0072` (columns `id, vehicle_id, plate, entry_time, status, photo_count, has_pass, left_keys`).
- `parking_sessions.payment_method` check is `parking_sessions_payment_method_check` (`0009`, values `cash, card, transfer, monthly_pass, exempt`).
- `parking_settings` has `lot_id`, `currency text not null default 'COP'` (`0068`), `business_timezone`, `whatsapp_auto`; RLS `settings_read` (`lot_id = current_lot_id()`), `settings_admin_write` (lot admins).
- `notifications(user_id, type, title, body, data, dedupe_key, lot_id)`; `type` has no check constraint (`0008`).
- Edge Functions in `supabase/volumes/functions/`: `admin-users`, `evidence-archive`, `hello`, `main`, `public-booking`, `public-evidence`, `push-dispatch`, `whatsapp-dispatch`. There is no `_shared` folder yet (NEW). Kong forwards `/functions/v1/*` without key-auth (`supabase/volumes/api/kong.yml`, service `functions-v1`); the runtime verifies a JWT only when `FUNCTIONS_VERIFY_JWT=true` (default `false` in `.env.example`).
- `supabase/jobs.sh` loops every `JOBS_INTERVAL_SECONDS`, calls `run <function>` via `psql` and `dispatch <url>` (POST with the service key) for `push-dispatch` and `whatsapp-dispatch`; `supabase/notifications-cron.sh` is the host-cron twin.
- Money: COP is stored in pesos (no decimals) and `Money` formats it; Wompi wants `amount_in_cents` (pesos x 100). The conversion lives only in the gateway adapter.

> `public_create_reservation` and other `public_*` RPCs may have changed while this change was written (`add-public-booking-captcha` is being implemented). This change does not touch them. Re-read the head of `supabase/migrations/` before copying any function body.

## Goals / Non-Goals

**Goals**

- A customer with the QR link pays the exact server-computed amount online and the operator closes the session with no cash step.
- Payment confirmation is cryptographically verified server-side and idempotent.
- Desk cash reconciliation stays correct: online money never enters `expected_cash`.
- Without Wompi keys (or with the per-lot switch off) the system behaves exactly as today.

**Non-Goals:** see `proposal.md`.

## Decisions

1. **Webhook is the only source of truth.** `payment-webhook` verifies the Wompi event checksum, normalises it and calls `apply_payment_event` (service role). The redirect page only polls `payment_intent_status`. Rejected: trusting `?id=` on the redirect (forgeable).
2. **Server prices, intent freezes the amount.** `create_session_payment_intent` computes the amount through `session_settlement` -> `fare_breakdown` and stores it in `payment_intents.amount`. The gateway checkout is signed with that amount, so the customer cannot change it, and `apply_payment_event` rejects an event whose amount or currency differs from the intent (`mismatch`).
3. **Grace window instead of recomputing on every minute.** The fare grows while the customer walks to the exit. Rule, evaluated at the exit instant `exit_at` used by `check_out`: if `exit_at <= online_paid_at + online_payment_grace_minutes` the charge is exactly `online_paid_amount`; otherwise the charge is `greatest(gross, online_paid_amount)` and the desk collects `charge - paid`. Pure function `online_settlement_amounts` holds this rule so SQL tests pin it.
4. **`online` is a server-only payment method.** `check_out` keeps rejecting `online` from the caller (`InvalidPaymentMethod`); the server sets it when `desk_due = 0` and `online_paid_amount > 0`. This also covers a paid session that has a monthly pass: the money is real, so the session is stored as `online` with `amount_charged = paid` and admins get a review notification.
5. **Invariant: `amount_charged = online_paid_amount + desk_due`**, `desk_due >= 0`. Therefore reports can derive the desk part as `amount_charged - online_paid_amount` and `revenue = cash + card + transfer + pass + exempt + online`.
6. **Online money is attributed to the shift that closes the session**, not to the shift open when the customer paid (the customer is not at any shift). It never touches `expected_cash`. Bank reconciliation by approval date is `report_online_payments`. Rejected: a separate "online shift" (no operator exists).
7. **One gateway port, one adapter, no gateway names in SQL or Dart.** `payment_intents.gateway text default 'wompi'` is data, not logic.
8. **No webhook => reconcile.** Wompi retries webhooks but a lot can be down; `payments-reconcile` (called from `jobs.sh`) asks the gateway for pending intents older than 10 minutes and feeds the result through the same `apply_payment_event`.
9. **Approved-after-expired still counts.** `expire_payment_intents` only moves `pending` rows to `expired`; an `APPROVED` event for an `expired` intent is applied (money was taken). An approval for a session that is already closed is recorded and raises an `online_payment_review` notification (refund decision is human).
10. **No overloads.** `check_out`, `check_out_preview`, `public_session_summary`, `shift_totals` keep their exact signatures (`create or replace`), so PostgREST has one candidate (the trap recorded in `docs/agent-memory.md` for `save_parking_spot` and `check_in`).
11. **Per-lot opt-in + currency guard.** `online_payments_enabled` default false; a CHECK forbids enabling it when `currency <> 'COP'`. The admin edits it from the settings page through the existing `parking_settings` update (no new RPC).
12. **Public attack surface is plate-keyed and throttled.** `create_session_payment_intent` allows at most 5 intents per session in the last hour (`PaymentThrottledError`) and answers `SessionNotFoundError` for both an unknown session and a wrong plate (no oracle).

## Data model

Use the next three free migration numbers, in this order. Statements are idempotent (`if not exists` / `drop ... if exists`) like earlier migrations.

### `<NEXT>_online_payments_schema.sql`

```sql
alter table public.parking_settings
    add column if not exists online_payments_enabled boolean not null default false,
    add column if not exists online_payment_grace_minutes integer not null default 15,
    add column if not exists online_payment_min_amount integer not null default 1500;

alter table public.parking_settings
    drop constraint if exists parking_settings_online_payment_check;
alter table public.parking_settings
    add constraint parking_settings_online_payment_check check (
        online_payment_grace_minutes between 5 and 120
        and online_payment_min_amount between 0 and 100000000
        and (not online_payments_enabled or currency = 'COP')
    );

alter table public.parking_sessions
    add column if not exists online_paid_amount integer not null default 0
        check (online_paid_amount >= 0),
    add column if not exists online_paid_at timestamptz;

alter table public.parking_sessions
    drop constraint if exists parking_sessions_payment_method_check;
alter table public.parking_sessions
    add constraint parking_sessions_payment_method_check check (
        payment_method is null
        or payment_method in ('cash','card','transfer','monthly_pass','exempt','online')
    );

create table if not exists public.payment_intents (
    id                     bigserial primary key,
    lot_id                 integer     not null references public.parking_lots(id),
    kind                   text        not null default 'session' check (kind in ('session')),
    session_id             integer     references public.parking_sessions(id),
    reference              text        not null unique,
    amount                 integer     not null check (amount > 0),
    currency               text        not null default 'COP' check (currency = 'COP'),
    gateway                text        not null default 'wompi',
    status                 text        not null default 'pending'
        check (status in ('pending','approved','declined','voided','error','expired')),
    gateway_transaction_id text,
    gateway_method         text,
    expires_at             timestamptz not null,
    approved_at            timestamptz,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now(),
    constraint payment_intents_target_check check (kind <> 'session' or session_id is not null)
);
create index if not exists ix_payment_intents_lot on public.payment_intents(lot_id, created_at desc);
create index if not exists ix_payment_intents_session on public.payment_intents(session_id, created_at desc);
create index if not exists ix_payment_intents_pending on public.payment_intents(created_at) where status = 'pending';
create unique index if not exists uq_payment_intents_transaction
    on public.payment_intents(gateway, gateway_transaction_id) where gateway_transaction_id is not null;

create table if not exists public.payment_events (
    id                     bigserial primary key,
    gateway                text        not null,
    gateway_transaction_id text        not null,
    gateway_status         text        not null,
    intent_id              bigint      references public.payment_intents(id) on delete set null,
    reference              text,
    amount                 integer,
    outcome                text        not null
        check (outcome in ('applied','ignored','unknown_reference','mismatch','late_closed')),
    payload                jsonb       not null default '{}'::jsonb,
    created_at             timestamptz not null default now(),
    unique (gateway, gateway_transaction_id, gateway_status)
);
create index if not exists ix_payment_events_intent on public.payment_events(intent_id);

alter table public.payment_intents enable row level security;
alter table public.payment_events enable row level security;
grant select on public.payment_intents to authenticated;
drop policy if exists payment_intents_admin_read on public.payment_intents;
create policy payment_intents_admin_read on public.payment_intents
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));
-- payment_events: RLS on, no policy, no grant: only the service role and
-- security definer functions read or write it.
```

Pure rule function (same file):

```sql
create or replace function public.online_settlement_amounts(
    p_gross integer, p_paid integer, p_paid_at timestamptz,
    p_exit timestamptz, p_grace_minutes integer
) returns jsonb language sql immutable set search_path = public as $$
    select jsonb_build_object(
        'grace_until', case when p_paid > 0 and p_paid_at is not null
                            then p_paid_at + make_interval(mins => p_grace_minutes) end,
        'grace_active', p_paid > 0 and p_paid_at is not null
                        and p_exit <= p_paid_at + make_interval(mins => p_grace_minutes),
        'charged', case
            when p_paid > 0 and p_paid_at is not null
                 and p_exit <= p_paid_at + make_interval(mins => p_grace_minutes) then p_paid
            else greatest(p_gross, p_paid) end,
        'desk_due', case
            when p_paid > 0 and p_paid_at is not null
                 and p_exit <= p_paid_at + make_interval(mins => p_grace_minutes) then 0
            else greatest(p_gross, p_paid) - p_paid end
    );
$$;
revoke all on function public.online_settlement_amounts(integer, integer, timestamptz, timestamptz, integer)
    from public, anon, authenticated;
```

`security definer` callers (`check_out`, ...) run as owner and can still call it.

### `<NEXT>_online_payments_rpcs.sql`

All functions: `language plpgsql`, `security definer`, `set search_path = public`. Functions for the Edge Functions end with `revoke all ... from public, anon, authenticated; grant execute ... to service_role;` (the revoke names `anon, authenticated` because Supabase default privileges grant new functions to them — the lesson of `0103`).

| Function | Signature | Grant | Returns |
|---|---|---|---|
| `session_settlement` | `(p_session_id integer, p_at timestamptz default null)` | none (internal; revoke from `public, anon, authenticated`) | `{session_id, lot_id, status, plate, currency, gross, has_pass, paid, due, grace_active, grace_until, enabled, min_amount, grace_minutes}` |
| `create_session_payment_intent` | `(p_session_id bigint, p_plate text)` | `service_role` | `{intent_id, reference, amount, currency, status, expires_at, grace_minutes}` |
| `apply_payment_event` | `(p_gateway text, p_event jsonb)` | `service_role` | `{applied boolean, duplicate boolean, outcome text, intent_id bigint, status text, session_id integer}` |
| `settle_payment_intent` | `(p_intent_id bigint)` | none (internal, revoke from `public, anon, authenticated`; called by `apply_payment_event`) | `{kind text, applied boolean, session_id integer}`; the only place that dispatches on `payment_intents.kind` (today only `session`; `add-pass-auto-renewal` re-declares it to add `pass`) |
| `payment_intent_status` | `(p_reference text, p_plate text)` | `anon, authenticated` | `{status, amount, session_id, paid_total, grace_until}` or `null` |
| `expire_payment_intents` | `()` | none (revoke; called by `jobs.sh` as superuser) | integer rows expired |
| `list_reconcilable_payment_intents` | `(p_older_than_minutes integer default 10)` | `service_role` | jsonb array `[{id, reference, gateway, amount}]` (status `pending`, created between 24 h and `p_older_than_minutes` ago, max 50) |
| `report_online_payments` | `(p_start_date date, p_end_date date)` | `authenticated` (calls `require_lot_admin()`) | `{start_date, end_date, total, count, items:[{intent_id, reference, gateway_transaction_id, gateway_method, amount, approved_at, session_id, plate, ticket_number, status}]}` for approved and voided intents in the lot's business-date window |

Behaviour:

- `session_settlement`: load the session (`for share` not needed), vehicle category, `has_pass` for `coalesce(p_at, now())` in the lot timezone (same predicate as `check_out_preview`), `gross = (fare_breakdown(category, entry_time, at, has_pass) ->> 'amount')::integer`, then `online_settlement_amounts(gross, online_paid_amount, online_paid_at, at, grace)`; `due = desk_due`. Does not check the switch (callers do).
- `create_session_payment_intent`: normalise the plate exactly like `public_session_summary` (`upper(regexp_replace(..., '\s', '', 'g'))`); unknown session or plate mismatch -> `SessionNotFoundError`; `status = 'closed'` -> `SessionAlreadyClosedError`; lot switch off -> `OnlinePaymentsDisabledError`; `due = 0` -> `NothingToPayError`; `due < online_payment_min_amount` -> `AmountTooLowError`; `currency <> 'COP'` -> `OnlinePaymentsDisabledError`; 5 intents for the session in the last hour -> `PaymentThrottledError`. Takes `pg_advisory_xact_lock(hashtext('payment_intent'), p_session_id::integer)`. If a `pending`, non-expired intent exists with the same amount, return it; otherwise mark pending ones `expired` and insert a new one with `reference = 'PM-' || upper(encode(gen_random_bytes(6), 'hex'))` (pgcrypto exists since `0001`) and `expires_at = now() + interval '30 minutes'`.
- `apply_payment_event` expects `p_event` keys `transaction_id text, reference text, status text ('APPROVED'|'DECLINED'|'VOIDED'|'ERROR'), amount integer (pesos), currency text, method text, occurred_at timestamptz, raw jsonb`. Algorithm: (1) insert into `payment_events` with `on conflict (gateway, gateway_transaction_id, gateway_status) do nothing`; no row inserted -> return `{applied:false, duplicate:true, outcome:'ignored'}`. (2) Lock the intent by reference `for update`; absent -> update event `outcome='unknown_reference'`, return `applied:false`. (3) Amount or currency differs from the intent -> `outcome='mismatch'`, notify lot admins (`online_payment_review`), return `applied:false`. (4) For `kind = 'session'` lock the session `for update` (order: intent, then session; `check_out` locks only the session); other kinds are handled entirely inside `settle_payment_intent`. (5) `APPROVED`: intent -> `approved` (`gateway_transaction_id`, `gateway_method`, `approved_at = now()`) unless already `approved`, then `settle_payment_intent(intent.id)` runs the side effect: if the session is `open` then `online_paid_amount += amount`, `online_paid_at = now()`, notify lot members `online_payment`; if the session is `closed` then `outcome='late_closed'` and notify `online_payment_review`. (6) `DECLINED`/`ERROR`: intent -> `declined`/`error` only when `pending` or `expired`; never downgrade `approved`. (7) `VOIDED`: intent -> `voided`; open session `online_paid_amount = greatest(online_paid_amount - amount, 0)`; always notify `online_payment_review`. Notifications use `dedupe_key = 'online_pay:' || intent_id || ':' || status || ':user:' || user_id` and `on conflict (dedupe_key) do nothing`, to every active lot member like `notify_session_event` does. All branches stamp `payment_events.outcome`.
- `payment_intent_status`: requires `reference` and plate to match the intent's session plate; otherwise `null`. `paid_total` is the session's `online_paid_amount`; `grace_until` from `online_paid_at`.
- Ordering inside a transaction: `now()` is constant per transaction (see `docs/agent-memory.md`); tests that need "after the window" set `online_paid_at` explicitly with an `update`.

### `<NEXT>_online_payments_checkout.sql`

Copy the LATEST body of each function (see Context for file numbers) and change only what is listed.

- `check_out` (same 11 parameters, same order): after `gross` is computed and before the discount block, read `paid := session.online_paid_amount`, `paid_at := session.online_paid_at` and the lot's `online_payment_grace_minutes`; `settle := public.online_settlement_amounts(gross, paid, paid_at, exit_at, grace)`; `gross := (settle ->> 'charged')::integer`; `desk_due := (settle ->> 'desk_due')::integer`. Discount rule: when `paid > 0`, `discount > desk_due` raises `InvalidDiscountError`. `amount := greatest(gross - discount, 0)`; `desk_due := greatest(desk_due - discount, 0)`. When `paid > 0 and desk_due = 0` set `method := 'online'` AFTER the pass override and clear `cash_in`/`card_kind`. The cash check becomes `cash_in < desk_due` and `cash_back := cash_in - desk_due`. Add `online_paid_amount` to the response JSON. The `InvalidPaymentMethod` list is NOT widened. If `paid > 0 and has_pass` insert the `online_payment_review` notification (dedupe `'online_pass:' || session.id || ':user:' || user_id`).
- `check_out_preview(p_session_id integer)`: add keys `online_paid_amount`, `online_paid_at`, `grace_active`, `grace_until`, `amount_due` (desk due now); `amount` keeps meaning "fare right now".
- `public_session_summary(p_session_id bigint, p_plate text)`: add keys `online_payments_enabled`, `online_paid_amount`, `amount_due`, `grace_until`, `online_min_amount`. For a closed session the new keys reflect stored values; `amount_due` is `0`.
- `shift_totals(p_shift_id bigint)`: `cash_sales`, `card_sales`, `transfer_sales`, `exempt_sales` become `sum(amount_charged - online_paid_amount) filter (where payment_method = ...)`; add `online_sales = coalesce(sum(online_paid_amount), 0)` over all closed sessions of the shift and the key `'online_sales'`. `expected_cash`, `revenue`, `pass_*` formulas are unchanged.
- `report_revenue` / `report_revenue_all`: `by_payment` rows are built from a `union all` of `(coalesce(payment_method,'unknown'), amount_charged - online_paid_amount)` and `('online', online_paid_amount)` where `online_paid_amount > 0`, grouped by method (and by lot in the `_all` variant exactly as it groups today). Totals (`total`) are unchanged.
- `open_sessions_view`: `create or replace view` appending two columns after `left_keys`: `s.online_paid_amount` and `(s.online_paid_at + make_interval(mins => coalesce(tz.grace, 15))) as online_grace_until`, extending the lateral subquery with `ps.online_payment_grace_minutes as grace`. Keep `with (security_invoker = true)` and the `grant select ... to authenticated`.

## Edge Functions

Shared files (NEW, allowlist `_shared` in `supabase/.gitignore` like `public-booking`): `supabase/volumes/functions/_shared/payment_gateway.ts` (port), `wompi_gateway.ts` (adapter), `http.ts` (`json()`, CORS, service-key REST helper, structured log line `{fn, status, ms, ...}` as in `whatsapp-dispatch`). Functions import with `../_shared/...`. A new function env var must also be added to the `functions` service in `supabase/docker-compose.yml` (rule recorded in `docs/agent-memory.md`).

Port (TypeScript):

```ts
export type GatewayEvent = {
  transactionId: string; reference: string;
  status: 'APPROVED' | 'DECLINED' | 'VOIDED' | 'ERROR' | 'PENDING';
  amount: number;            // pesos (integer minor units of the lot currency)
  currency: string; method: string; occurredAt: string; raw: unknown;
};
export interface PaymentGateway {
  readonly name: string;
  isConfigured(): boolean;
  createCheckout(i: { reference: string; amount: number; currency: string;
                      redirectUrl: string; expiresAt: string }): Promise<{ checkoutUrl: string }>;
  verifyEvent(rawBody: string, headers: Headers): Promise<GatewayEvent | null>; // null = bad signature
  findByReference(reference: string): Promise<GatewayEvent[]>;
}
```

### `payment-intent`

- `POST /functions/v1/payment-intent`, headers `apikey: <anon>` and `Authorization: Bearer <anon>` (like `public-evidence`; the JWT is not required), `Content-Type: application/json`. `OPTIONS` answers CORS. Body `{"session": 55, "plate": "ABC123"}`.
- Not configured (`WOMPI_PUBLIC_KEY`, `WOMPI_PRIVATE_KEY`, `WOMPI_INTEGRITY_SECRET`, `WOMPI_EVENTS_SECRET` or `PAYMENT_REDIRECT_BASE_URL` empty): `503 {"message":"PaymentsNotConfiguredError"}` before any DB call.
- Success `200`: `{"intent_id": 9, "reference": "PM-1A2B3C4D5E6F", "amount": 6000, "currency": "COP", "checkout_url": "https://checkout.wompi.co/p/?...", "expires_at": "<iso>", "grace_minutes": 15}`.
- Errors `{"message":"<Name>Error"}`: `400 InvalidLinkError` (bad body), `404 SessionNotFoundError`, `409 SessionAlreadyClosedError | OnlinePaymentsDisabledError | NothingToPayError`, `422 AmountTooLowError`, `429 PaymentThrottledError`, `503 PaymentsNotConfiguredError`.
- Flow: validate body -> `rpc/create_session_payment_intent` with the service key -> `gateway.createCheckout` -> respond. The redirect URL is `${PAYMENT_REDIRECT_BASE_URL}/evidence?session=<id>&pay=<reference>`.

### `payment-webhook`

- `POST /functions/v1/payment-webhook` with the raw Wompi event body. It MUST stay reachable without a JWT and from the public internet (`<SUPABASE_PUBLIC_URL>/functions/v1/payment-webhook` is the URL the owner registers in the Wompi dashboard); therefore `FUNCTIONS_VERIFY_JWT` must remain `false`. The checksum is the only authentication.
- ASSUMPTION (owner/implementer must confirm against current Wompi docs before go-live): Wompi sends `{"event":"transaction.updated","data":{"transaction":{...}},"signature":{"properties":["transaction.id","transaction.status","transaction.amount_in_cents"],"checksum":"<hex>"},"timestamp":<unix seconds>}` (and the same checksum in header `X-Event-Checksum`), and `checksum = hex(SHA-256(concat(values of the listed properties, in order) + timestamp + WOMPI_EVENTS_SECRET))`.
- Verification: read the raw body once; parse; build the concatenation from `signature.properties`; compute SHA-256 with Web Crypto; compare with a constant-time comparison to `signature.checksum`; reject if the header exists and differs. Do NOT reject by `timestamp` age (Wompi retries for up to 24 h; replay is harmless because the application is idempotent).
- Responses: `401 {"message":"InvalidSignatureError"}` (nothing written); `200 {"applied": true|false, "outcome": "..."}` after `apply_payment_event` (duplicates and unknown references are `200` so Wompi stops retrying); `200 {"ignored": true}` for non-`transaction.updated` events and `PENDING` transactions; `503 {"configured": false}` when `WOMPI_EVENTS_SECRET` is empty; `500` when the RPC fails (Wompi retries).
- The function converts `amount_in_cents` to pesos only if divisible by 100, else it forwards `amount = -1` so the RPC records `mismatch`.

### `payments-reconcile`

- `POST /functions/v1/payments-reconcile`, `Authorization: Bearer <service role>` only (`403 {"message":"Forbidden"}` otherwise, as `whatsapp-dispatch`). No keys: `200 {"configured": false, "checked": 0}`.
- Calls `rpc/list_reconcilable_payment_intents`, then `gateway.findByReference(reference)` for each (ASSUMPTION: `GET {WOMPI_API_URL}/transactions?reference=<reference>`, `Authorization: Bearer WOMPI_PRIVATE_KEY`; confirm), and sends every non-`PENDING` result to `apply_payment_event`. Response `{"configured": true, "checked": n, "applied": m}`. Called by `supabase/jobs.sh` (`dispatch "${API_URL}/functions/v1/payments-reconcile"`, plus `run expire_payment_intents`) and `supabase/notifications-cron.sh`.

### Environment (functions service only; none reaches the client)

| Var | Meaning | Default |
|---|---|---|
| `WOMPI_PUBLIC_KEY` | merchant public key (`pub_...`) used in the checkout URL | empty = inert |
| `WOMPI_PRIVATE_KEY` | private key (`prv_...`) for `findByReference` | empty = inert |
| `WOMPI_INTEGRITY_SECRET` | signs the checkout (`SHA-256(reference + amount_in_cents + currency + secret)`; ASSUMPTION to confirm) | empty = inert |
| `WOMPI_EVENTS_SECRET` | verifies webhooks | empty = inert |
| `WOMPI_ENV` | `sandbox` or `production`; picks default URLs | `sandbox` |
| `WOMPI_API_URL` | API base | `https://sandbox.wompi.co/v1` (sandbox) / `https://production.wompi.co/v1` |
| `WOMPI_CHECKOUT_URL` | Web Checkout base | `https://checkout.wompi.co/p/` |
| `PAYMENT_REDIRECT_BASE_URL` | public origin of the web app, e.g. `https://parking.example.com` | empty = inert |

All are passed through `supabase/docker-compose.yml` (`${VAR:-}` form) and documented in `.env.example` and `docs/runbook-secrets.md` (rotation: change the secret, restart `functions`).

## State machines

Intent: `pending -> approved | declined | error | expired`; `expired -> approved | declined | error` (late events); `approved -> voided`; `approved` never goes back to `pending`/`declined`. Terminal for payment: `approved`, `voided`.

Session payment: `unpaid (paid=0) -> paid (paid>0, grace running) -> grace expired (desk_due may be >0) -> closed`; `paid -> unpaid` only on `VOIDED` while open.

## Sequences

1. Customer pays: page `GET evidence` (existing) shows `summary.amount_due` and the Pay button -> `payment-intent` -> redirect to Wompi -> Wompi `POST payment-webhook` -> `apply_payment_event` -> notification to the desk -> Wompi redirects to `/evidence?session&pay=<reference>` -> plate gate -> `payment_intent_status` polled every 3 s up to 180 s -> on `approved` the page reloads the summary and shows "leave before <grace_until>".
2. Operator exit inside the window: list shows the "Paid online" chip -> `check_out_preview` (`amount_due = 0`) -> dialog without payment choice -> `check_out(...)` -> stored `online`, `amount_charged = paid`.
3. Exit after the window: preview shows `grace_active = false`, `amount_due > 0` -> dialog collects only the difference with the operator's method -> `check_out` stores the chosen method, `amount_charged = gross`, `online_paid_amount` kept.
4. Lost webhook: `jobs.sh` -> `payments-reconcile` -> `apply_payment_event` (same idempotent path).

## Flutter

New feature `lib/features/online_payments/`:

```
domain/entities/payment_intent.dart            // PaymentIntent{intentId:int, reference:String, amount:int, currency:String, checkoutUrl:String, expiresAt:DateTime, graceMinutes:int}
domain/entities/payment_status.dart            // enum PaymentStatus{pending,approved,declined,voided,error,expired}; PaymentIntentStatus{status, amount:int, sessionId:int, paidTotal:int, graceUntil:DateTime?}
domain/repositories/online_payment_repository.dart // createIntent({required int sessionId, required String plate}); status({required String reference, required String plate}) -> PaymentIntentStatus?
application/online_payment_cubit.dart          // ResilientCubit<OnlinePaymentState>
infrastructure/models/payment_intent_dto.dart
infrastructure/online_payment_remote_data_source.dart   // functions.invoke('payment-intent'), rpc('payment_intent_status')
infrastructure/online_payment_repository_impl.dart
presentation/widgets/pay_online_panel.dart
```

`OnlinePaymentState` (sealed, Equatable): `OnlinePaymentInitial`, `OnlinePaymentLoading` (creating the intent or polling; the panel shows a skeleton matching the metric cards), `OnlinePaymentReady` (`amountDue:int`, `paid:int`, `graceUntil:DateTime?`, `status:PaymentStatus?`, `submission:Submission`), `OnlinePaymentNothingDue` (empty state: nothing to pay or already paid), `OnlinePaymentFailure` (error state with `failure:Failure`, Retry). Cubit methods: `prepare(PublicSessionSummary)`, `pay({sessionId, plate})` returns the `checkoutUrl` through `SubmissionSucceeded`, `track({reference, plate})` polling with a `Timer` (3 s, stop after 180 s or a final status), `close()` cancels the timer.

Changes in existing code:

- `lib/features/evidence/domain/entities/public_evidence.dart`: `PublicSessionSummary` gains `onlinePaymentsEnabled:bool=false`, `onlinePaidAmount:int=0`, `amountDue:int=0`, `graceUntil:DateTime?`, `onlineMinAmount:int=0` (parse the new JSON keys; absent keys keep defaults so old backends work).
- `lib/features/evidence/presentation/public_evidence_page.dart`: new param `payReference` (`String?`); `_EvidenceBody` renders `PayOnlinePanel` under the fare metric when `summary.isOpen && summary.onlinePaymentsEnabled`. The button opens `checkoutUrl` with `launchUrl(uri, webOnlyWindowName: '_self')` (`url_launcher` already a dependency).
- `lib/app/router/app_router.dart`: the `evidencePath` route wraps the page in `MultiBlocProvider` with `EvidenceCubit` and `OnlinePaymentCubit` and passes `payReference: state.uri.queryParameters['pay']`. `route_access.dart` is NOT changed (`/evidence` is already public).
- `lib/app/di/modules/online_payments_module.dart` (NEW): `registerOnlinePaymentsModule(GetIt sl)`: lazy singletons for the data source and repository, factory for the cubit; call it in `registerAllModules` in `lib/app/di/injection.dart` right after `registerEvidenceModule(sl)`.
- `check_out`: `OpenSession` + `OpenSessionDto` gain `onlinePaidAmount:int=0`, `onlineGraceUntil:DateTime?` (select string in `check_out_remote_data_source.dart` gains `online_paid_amount, online_grace_until`); `CheckOutPreview` gains `onlinePaidAmount`, `amountDue`, `graceActive`, `graceUntil` (`amountDue` defaults to `amount` when the key is absent); `CheckOutReceipt` + DTO gain `onlinePaidAmount:int=0`. `check_out_page.dart` shows a chip "Paid online" on tiles with `onlinePaidAmount > 0`; `payment_method_dialog.dart` shows paid, balance and, when `amountDue == 0`, hides the method and cash fields (confirm button = "Confirm exit"). The client still sends a normal method (`cash`) in that case; the server overrides it.
- `lib/core/receipt/payment_method.dart`: `paymentMethodLabel` returns `l10n.paymentOnline` for `'online'` before the enum lookup. The `PaymentMethod` enum is NOT extended (`PaymentMethod.values` drives the method buttons in the dialog).
- `lib/core/receipt/receipt_data.dart`: `ReceiptData.onlinePaidAmount` (`int`, default `0`); `lib/core/receipt/receipt_labels.dart`: `onlinePaid` label and `'online'` in `_paymentEs` (`'En linea'`) / `_paymentEn` (`'Online'`) (ASCII only, thermal printers); `receipt_card.dart`, `esc_pos_generator.dart` and `system_dialog_receipt_printer.dart` print the paid-online row when `> 0`.
- `shifts`: `ShiftSummary.onlineSales:int=0` (`json['online_sales']`), a row in `shift_page.dart` and `shift_pdf.dart` (`l10n.shiftOnlineSales`).
- `settings`: `ParkingSettings` + `ParkingSettingsDto` gain `onlinePaymentsEnabled:bool=false`, `onlinePaymentGraceMinutes:int=15`, `onlinePaymentMinAmount:int=1500` (follow the file's existing JSON-key convention); `hive_adapters.g.yaml` regenerates with `dart run build_runner build --delete-conflicting-outputs`; `settings_page.dart` adds an "Online payments" section (switch, grace minutes, minimum amount; the switch is disabled with `settingsOnlineCopOnly` when `currency != 'COP'`).
- `reports`: `ReportRepository.getOnlinePayments({required DateTime from, required DateTime to})`, entity `OnlinePaymentReport` in `lib/features/reports/domain/entities/online_payment_report.dart`, a section in `reports_page.dart`; `by_payment` labels already use `paymentMethodLabel`.
- `notifications`: `notification_routes.dart` maps `online_payment` and `online_payment_review` to the plate history route (`/history?plate=...`) like `check_out`; `notifications_page.dart` adds the two type labels and icons.
- `lib/core/network/supabase_error_mapper.dart`: add `OnlinePaymentsDisabledError`, `NothingToPayError`, `AmountTooLowError`, `PaymentsNotConfiguredError`, `PaymentThrottledError`, `InvalidLinkError` to `_domainCodes`; `lib/core/l10n/failure_messages.dart` `_byCode` maps them to the new `error*` keys. The data source also maps a `FunctionException` body `{"message": "<Name>Error"}` to `ValidationFailure(message, message)` for every status (including 429/503) — the same contract `public_booking_remote_data_source.dart` follows.

### New l10n keys (`lib/l10n/app_es.arb` / `app_en.arb`, then `flutter gen-l10n`)

| Key | ES | EN |
|---|---|---|
| `paymentOnline` | En línea | Online |
| `onlinePayTitle` | Paga desde tu celular | Pay from your phone |
| `onlinePayDue` | Valor a pagar | Amount due |
| `onlinePayAction` | Pagar en línea | Pay online |
| `onlinePayHint` | Tarjeta, PSE o Nequi. Después de pagar tienes {minutes} minutos para salir. | Card, PSE or Nequi. After paying you have {minutes} minutes to leave. |
| `onlinePayChecking` | Confirmando tu pago… | Confirming your payment… |
| `onlinePayApproved` | Pago recibido. Muestra esta pantalla al salir. | Payment received. Show this screen at the exit. |
| `onlinePayDeclined` | El pago no fue aprobado. Puedes intentarlo de nuevo. | The payment was not approved. You can try again. |
| `onlinePayPending` | Aún no confirmamos tu pago. Si ya pagaste, espera un momento. | We have not confirmed your payment yet. If you already paid, wait a moment. |
| `onlinePayGraceUntil` | Sal antes de las {time} | Leave before {time} |
| `onlinePayLate` | Si pasas de esa hora, pagas la diferencia en caja. | If you stay past that time, you pay the difference at the desk. |
| `onlinePayNothingDue` | No tienes nada por pagar. | You have nothing to pay. |
| `checkOutPaidOnline` | Pagado en línea | Paid online |
| `checkOutBalanceDue` | Saldo en caja | Balance at the desk |
| `checkOutNoCashDue` | Sin cobro en caja: ya pagó en línea | Nothing to collect: paid online |
| `checkOutGraceExpired` | Venció la tolerancia de salida; se cobra la diferencia | The exit window is over; the difference is due |
| `checkOutOnlineUnknownOffline` | Sin conexión no se puede confirmar si este vehículo pagó en línea | Offline: we cannot confirm whether this vehicle paid online |
| `shiftOnlineSales` | Pagos en línea | Online payments |
| `receiptPaidOnline` | Pagado en línea | Paid online |
| `settingsOnlinePayments` | Pagos en línea | Online payments |
| `settingsOnlinePaymentsHint` | Permite que el cliente pague desde el QR del recibo. Requiere credenciales Wompi en el servidor. | Lets customers pay from the receipt QR. Requires Wompi credentials on the server. |
| `settingsOnlineGraceMinutes` | Minutos para salir después de pagar | Minutes to leave after paying |
| `settingsOnlineMinAmount` | Valor mínimo en línea | Minimum online amount |
| `settingsOnlineCopOnly` | Solo disponible para sedes en COP | Only available for COP sites |
| `notifTypeOnlinePayment` | Pago en línea | Online payment |
| `notifTypeOnlinePaymentReview` | Pago en línea por revisar | Online payment to review |
| `reportOnlinePayments` | Pagos en línea | Online payments |
| `reportOnlineReference` | Referencia | Reference |
| `errorOnlinePaymentsDisabled` | Los pagos en línea no están activos en esta sede | Online payments are not enabled at this site |
| `errorNothingToPay` | No hay nada por pagar | There is nothing to pay |
| `errorAmountTooLow` | El valor es menor al mínimo para pagar en línea; paga en caja | The amount is below the online minimum; pay at the desk |
| `errorPaymentsNotConfigured` | El pago en línea no está disponible por ahora; paga en caja | Online payment is unavailable right now; pay at the desk |
| `errorPaymentThrottled` | Demasiados intentos de pago. Intenta de nuevo en una hora o paga en caja | Too many payment attempts. Try again in an hour or pay at the desk |

### Offline behaviour (AGENTS section 5)

- Creating an intent, polling and the public page need the network; there is no queue and nothing is stored in the Hive outbox.
- Operator check-out may still queue offline (existing behaviour). The offline receipt stays `pendingSync` with no amount. The server decides the final method and amount on replay. Risk: an operator offline cannot see that the customer paid online; the dialog shows `checkOutOnlineUnknownOffline` when the connectivity check fails and the cached open-session row has `onlinePaidAmount == 0`. Operators are trained not to collect cash from a customer who shows a "payment received" screen.
- Cash intake and shifts remain strictly online (unchanged).

## Security analysis

| Actor | Can |
|---|---|
| `anon` (customer) | `payment_intent_status(reference, plate)`; call `payment-intent` (plate-keyed, throttled); read the summary through `public-evidence` / `public_session_summary`. Cannot execute `create_session_payment_intent`, `apply_payment_event`, `session_settlement`, `list_reconcilable_payment_intents`. |
| `authenticated` operator | Read `parking_sessions.online_paid_*` and `open_sessions_view`; `check_out` (cannot send `online`). Cannot read `payment_intents` or `payment_events`. |
| `authenticated` lot admin | Read `payment_intents` of the active lot (`payment_intents_admin_read`); `report_online_payments`; edit the three settings columns. |
| `service_role` (Edge Functions only) | Execute the three service RPCs. |

- Lot isolation: every row carries `lot_id`; `create_session_payment_intent` copies the session's lot; `payment_intents_admin_read` uses `current_lot_id()` + `is_lot_admin(lot_id)`; `report_online_payments` calls `require_lot_admin()`.
- Spoofing: a forged webhook fails the checksum; a replay is a no-op (unique event key); an altered amount cannot match the signed checkout nor the stored amount.
- Enumeration: wrong plate and unknown session are indistinguishable; reference is 48 random bits and the status RPC also needs the plate.
- Secrets live only in the `functions` service env; the client has no payment key.
- Audit: `payment_intents`/`payment_events` are the audit trail; `record_audit` triggers are not attached to them.

## Risks / Trade-offs

- [Customer pays, then the desk collects cash again] -> the chip, the preview and the dialog make the paid state explicit; the server rejects double collection by setting `desk_due = 0`.
- [Gateway fee on small amounts] -> `online_payment_min_amount`.
- [Wompi API details differ from the assumptions above] -> they are isolated in `wompi_gateway.ts` and marked ASSUMPTION; the SQL contract is gateway-neutral.
- [The window forgives a higher fare] -> by design (customer-friendly, bounded to `online_payment_grace_minutes`, default 15).
- [Online money attributed to the closing shift] -> documented; reconcile with `report_online_payments`.
- [Refunds are manual] -> `VOIDED` and late approvals create admin notifications; no refund automation.

## Migration Plan

1. Apply the three migrations in order (additive; existing lots are unaffected because `online_payments_enabled = false`).
2. Add the `WOMPI_*` vars to `.env`, restart `functions`, register `<SUPABASE_PUBLIC_URL>/functions/v1/payment-webhook` in the Wompi dashboard (sandbox first).
3. Enable the switch per lot in Ajustes (COP lots only), after the web app with the new page is deployed.
4. Rollback: switch the lot off (immediate); reverting the migrations means restoring the `0072`/`0073`/`0077`/`0024`/`0039` function bodies and the check constraint.

## Open Questions (owner must answer)

1. One Wompi merchant account per deployment, or per lot? (This design: per deployment.)
2. Confirm the Wompi minimum amount per method and the default `online_payment_min_amount` (1500 here is an assumption).
3. Confirm the Wompi checksum/signature algorithms, the `reference` rules and the reconcile endpoint (ASSUMPTIONS above).
4. Grace window default (15 min) and the rule "inside the window the charge equals what was paid, even if the fare rose".
5. Who decides refunds for `VOIDED` / late / pass-covered payments, and how are they communicated to the customer?
6. Should an approved online payment also be sent as a WhatsApp receipt when `whatsapp_auto` is on? (Not included.)
7. Fiscal: online payments are subject to the invoicing change (`add-electronic-invoicing`); who is the invoice issuer for sessions paid online?
