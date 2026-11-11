# Design — merchant validations

## Context

Neighbouring businesses ("convenios") already get free or discounted parking
through the admin-only manual discount of `check_out`
(`p_discount_amount` + `p_discount_reason`, stored in
`parking_sessions.discount_amount/reason/by/at`, `0072_billing_integrity.sql`).
That works, but it has no merchant identity, no caps, no permission model (an
admin must be at the desk) and no way to tell a merchant what it owes.

The fare is computed inside `check_out` today; `check_out_preview` and
`public_session_summary` (`0077_public_session_summary.sql`) show the same
numbers through separate copies of the logic. Adding automatic adjustments to
one of them without a single source of truth would drift immediately.

## Decisions

1. **`fare_quote` becomes the only place that computes what a session owes.**
   It takes the session id, the exit instant and the manual discount inputs,
   and returns gross, the ordered adjustment lines and the amount due. The four
   consumers (`check_out`, `check_out_preview`, `public_session_summary`,
   `vehicle_history`) call it instead of duplicating arithmetic.
   `check_out` keeps its signature (11 arguments) and writes the result.
2. **A merchant is a token + PIN, not a role.** A third `merchant` role would
   have to be threaded through every lot-scoped RLS policy, `operatorRoutes`
   and `current_lot_id()`; and a merchant is not staff. The public page
   (`/validate?m=<token>`) authenticates with the merchant's private token and
   a 6-digit PIN, and the server validates through service-definer RPCs that
   never expose another merchant's rows. Same pattern as `/reserve` and
   `/evidence`.
3. **A validation is per session, not per visit.** One row in
   `merchant_validations` per (merchant, session); the benefit is applied when
   the session is closed, never while it is open. Revoking is allowed only
   while the session is open.
4. **The benefit is one rule per merchant**: `free_minutes`, `percentage` or
   `fixed_amount`, with an optional `max_amount`. Multiple rules, purchase
   thresholds and time windows are out of scope (see proposal).
5. **Adjustments are additive and ordered**: automatic benefits first (oldest
   validation wins when `merchant_max_per_session > 1`), the manual discount
   last. A percentage applies to the current amount at its turn; a fixed
   amount and `free_minutes` are absolute. The result never goes below zero.
6. **Settlement is a report, not a balance.** `merchant_paid` validations
   produce an amount owed; `courtesy` ones are a cost of the lot. Invoicing the
   merchant is `add-electronic-invoicing`'s job.

## Data model

```sql
create table public.merchants (
    id             serial primary key,
    lot_id         integer not null references public.parking_lots(id),
    name           varchar(120) not null,
    kind           text not null default 'free_minutes'
                   check (kind in ('free_minutes', 'percentage', 'fixed_amount')),
    free_minutes   integer not null default 0 check (free_minutes between 0 and 1440),
    percentage     integer not null default 0 check (percentage between 0 and 100),
    fixed_amount   integer not null default 0 check (fixed_amount >= 0),
    max_amount     integer,                      -- per validation, null = none
    billing_mode   text not null default 'merchant_paid'
                   check (billing_mode in ('merchant_paid', 'courtesy')),
    daily_cap      integer,                      -- validations per day, null = none
    monthly_cap    integer,
    token_hash     text not null,                 -- sha-256 of the link token
    pin_hash       text not null,                 -- sha-256(pin || token)
    pin_failures   integer not null default 0,
    locked_until   timestamptz,
    active         boolean not null default true,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    unique (lot_id, name)
);

create table public.merchant_validations (
    id            bigserial primary key,
    lot_id        integer not null,
    merchant_id   integer not null references public.merchants(id) on delete restrict,
    session_id    integer not null references public.parking_sessions(id) on delete cascade,
    source        text not null check (source in ('public', 'desk')),
    created_by    integer references public.users(id),   -- null on the public page
    status        text not null default 'pending'
                  check (status in ('pending', 'applied', 'revoked', 'forfeited')),
    reason        text,
    amount        integer not null default 0,            -- filled when applied
    created_at    timestamptz not null default now(),
    applied_at    timestamptz,
    revoked_by    integer references public.users(id),
    revoked_at    timestamptz,
    revoke_reason varchar(200),
    unique (merchant_id, session_id)
);

alter table public.parking_sessions
    add column if not exists gross_amount integer,
    add column if not exists fare_adjustments jsonb not null default '[]'::jsonb;

alter table public.parking_settings
    add column if not exists merchant_max_per_session integer not null default 1
        check (merchant_max_per_session between 0 and 5);
```

`token_hash` and `pin_hash` are SHA-256 (`pgcrypto`), the same shape the
device keys use in `add-device-gateway`. The link token is generated with
`gen_random_bytes(24)` and shown once; rotating it invalidates the old link.

## RPCs

| RPC | Role | Notes |
| --- | --- | --- |
| `list_merchants` / `save_merchant` / `delete_merchant` | lot admin | CRUD; `save_merchant` returns the link token only on create/rotate |
| `set_merchant_pin` / `rotate_merchant_token` | lot admin | invalidate the previous credential |
| `set_merchant_policy(p_max_per_session)` | lot admin | `parking_settings.merchant_max_per_session` |
| `add_merchant_validation(p_merchant_id, p_plate)` | operator | desk path; resolves the open session by plate |
| `revoke_merchant_validation(p_id, p_reason)` | lot admin | only while the session is open |
| `merchant_portal(p_token)` | anon | merchant identity (name, benefit copy, today's usage) or null |
| `merchant_validate(p_token, p_pin, p_plate)` | anon | the public page's validation |
| `report_merchant_settlement(p_from, p_to)` | lot admin | per merchant: validations, applied, forfeited, discounted, amount owed |
| `fare_quote(p_session_id, p_exit_time, p_discount_amount, p_discount_reason)` | authenticated | single source of the amounts; also used internally by `check_out` |

`merchant_portal` and `merchant_validate` are `security definer`, revoked from
`public` and granted to `anon, authenticated` (Supabase default privileges hand
new functions to `anon`; the `revoke` must name it).

## Amount composition

```
gross        = fare_breakdown(session, exit_time)         -- billing capability
adjustments  = [applied validations, oldest first]
amount_due   = gross − Σ adjustments − manual_discount     (never below 0)
```

- `free_minutes`: the benefit is computed on the stay **minus** the free
  minutes: `gross − quote(exit − free_minutes)`, clamped to `max_amount`.
- `percentage`: `round(current × percentage / 100)`, clamped to `max_amount`.
- `fixed_amount`: `min(fixed_amount, current)`, clamped to `max_amount`.
- The sum of adjustments never exceeds `gross`; leftover manual discount is
  clamped, and `InvalidDiscountError` is raised only when it exceeds the amount
  due after adjustments.

`fare_quote` returns:

```json
{ "gross": 9000, "adjustments": [{"merchant_id": 3, "kind": "free_minutes", "amount": 3000}],
  "discount_amount": 0, "amount_due": 6000 }
```

`check_out` stores `gross_amount`, `fare_adjustments` and
`amount_charged = amount_due`, so a reprint from history recomputes nothing.

## Validation rules (public and desk)

- The plate must have an **open** session in the merchant's lot; otherwise
  `SessionNotFoundError`.
- One validation per (merchant, session) (`unique`); a second attempt raises
  `AlreadyValidatedError`.
- At most `merchant_max_per_session` validations per session across merchants
  (0 disables the feature); `MerchantLimitError` otherwise.
- Per-merchant `daily_cap` / `monthly_cap` counted on validations that are not
  revoked, in the lot's business timezone; `MerchantCapError` otherwise.
- Wrong PIN increments `pin_failures`; 5 failures lock the merchant for 15
  minutes (`MerchantLockedError`). A successful call resets the counter.
- The token is compared by hash; an unknown token returns null from
  `merchant_portal` and `MerchantNotFoundError` from `merchant_validate` (no
  distinction between "wrong token" and "unknown", to avoid enumeration).
- All public calls take an advisory lock per token, mirroring the booking
  throttle, so a burst cannot bypass the caps.

## Security and audit

- RLS on both tables: read for lot members (admin sees all, operator sees the
  active merchant list to validate at the desk), write only through RPCs.
- `merchants` and `merchant_validations` get the existing `record_audit()`
  trigger: create/update/rotate on the merchant, add/revoke/apply on the
  validation (actor, timestamp, before/after).
- The public RPCs never return plate lists, session ids or another merchant's
  data; the response carries only the merchant name, the applied amount and a
  human-readable status.
- A validation is `forfeited` when the session closes without the merchant
  benefit being usable (for example the manual discount already zeroed the
  fare); the settlement report counts them separately.

## Integration points

- **Check-out dialog**: an optional "Convenio" picker (active merchants of the
  lot) that calls `add_merchant_validation`; the preview shows each adjustment
  line and the amount due.
- **Receipt** (screen, PDF, thermal) and **vehicle history reprint**: a
  "Convenio <merchant>: −$X" line per adjustment and the gross amount.
- **Public session page** (`/evidence?session=…&plate=…`): the same lines, read
  from `public_session_summary`.
- **`/validate?m=<token>`**: new public page (Flutter route, like `/reserve`),
  mobile-first: merchant name, benefit copy, plate field (or QR from the entry
  receipt), PIN pad, result.
- **Admin screen** `/merchants` (deferred route): list with today's usage,
  create/edit, show-key-once dialog, rotate, disable, settlement report with
  CSV/PDF share using the existing report widgets.
- **`add-electronic-invoicing`**: the document's amount is `amount_charged`;
  adjustments are informational lines, not separate invoices.
- **`add-cash-anomaly-detection`**: `anomaly_zero_charge_excluded` returns true
  for a session whose zero charge comes from a merchant benefit.

## Trade-offs and rejected alternatives

- **A merchant role in GoTrue**: rejected — every lot policy and route guards
  assume "authenticated lot member = staff"; a wrong assumption there is a data
  leak, not a UI bug.
- **Free-text validation codes**: rejected — a merchant cashier must not need
  the app nor an operator; token + PIN keeps the desk out of the loop.
- **Computing adjustments in Dart**: rejected — the fare must be authoritative
  on the server (offline replay, reprints, reports).
- **Applying the benefit while the session is open**: rejected — the benefit is
  a payment-time decision; doing it live would need a running recompute and
  would change the public page on every validation.
- **A balance ledger per merchant**: out of scope; the settlement report is the
  input for whatever invoicing the lot uses.

## Risks

- **Rounding**: percentage and free-minutes benefits must round the same way as
  `billing` (ceil-to-hour, then round to the nearest peso). Tests pin the
  fixtures.
- **Cap bypass**: caps are counted inside the same transaction as the insert,
  under the token advisory lock; a concurrent double-tap is rejected by the
  unique constraint.
- **Operator fraud**: an operator can validate at the desk for any merchant;
  the validation is audited with the actor and shows in the anomaly rules
  (`add-cash-anomaly-detection`).
- **Token leakage**: the link is shown once and rotatable; it only allows
  validations, never reading sessions or money.

## Testing strategy

- SQL: one `do $$` block per named case in `supabase/tests/rpc_test.sql`
  (`-- merchant validations`), covering success, each limit, the lockout, the
  amount composition (free minutes, percentage, fixed, cap), revocation,
  settlement totals, role isolation and RLS on both tables.
- Flutter: `test/features/merchants/**` for the repository/cubit, the public
  validation page (states, PIN errors, success), the desk picker, the receipt
  lines and the settlement report; `test/helpers/fake_merchant_repository.dart`.
- Money always through `Money` and minor units; the CSV uses raw integers.
