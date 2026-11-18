## Context

Verified in the code (latest definitions, not the first ones):

- `check_out` (`0072_billing_integrity.sql`, 11 parameters, last `p_cash_received integer default null`) writes `amount_charged`, `payment_method`, `lost_ticket`, `discount_*`, `shift_id` in ONE `update public.parking_sessions set status = 'closed', ...`. A row trigger `after update of status` therefore sees the final `amount_charged`, `payment_method`, `lost_ticket`, `exit_time` and (after `add-merchant-validations`) `fare_adjustments` of the closing session, inside the same transaction.
- `check_in` (`0098_reservation_grace_setting.sql`) takes 11 parameters with trailing defaults; adding one would create an overload trap (`docs/agent-memory.md`: the 8-argument overload "must stay dropped"). This change does not touch `check_in`: progress is a separate read RPC.
- Plates are a global registry (`vehicles.plate`, unique), stored as `upper(regexp_replace(plate, '\s', '', 'g'))` (same normalisation in `check_in`, `0021`, `0040`, `0063`). A session reaches its plate through `parking_sessions.vehicle_id -> vehicles.plate`. A loyalty account is per `(lot_id, plate)`.
- `parking_sessions.payment_method` is `cash|card|transfer|monthly_pass|exempt` (+ `online` after `add-online-payments`); `lost_ticket boolean`; `amount_charged integer`; `exit_time`, `entry_time`; `lot_id`. `status` check is `open|closed`: NO function voids or reopens a closed session today (`add-electronic-invoicing` design says the same). "Voided session reverses progress" is therefore delivered as an internal function that a future void feature calls.
- `parking_settings` is versioned (`0105`): new columns join automatically, an RPC write bumps `version`. The Flutter `ParkingSettings` entity is NOT extended, so queued offline settings diffs never carry loyalty columns.
- `record_audit()` (`0031`) strips only a column named `pin_hash`; loyalty tables hold no secrets. `audit_log` is readable by platform admins (`is_admin()`).
- Merchants (`add-merchant-validations`, merged first) owns `fare_quote`, the columns `parking_sessions.gross_amount` and `fare_adjustments`, and two no-op hooks. This change replaces `fare_reward_step(p_session_id integer, p_running integer, p_merchant_total integer) returns jsonb` with `create or replace` and nothing else of the quote.
- Entry receipt QR payload is the plate; check-out receipts carry no QR (`docs/agent-memory.md` "Receipt QR").

## Goals / Non-Goals

**Goals**

- Every N paid visits of a plate earn one reward, configurable per lot, inert until enabled.
- The reward is a server-computed line in the fare composition: previewed, receipted, stored and reportable, never computed in Dart.
- Anti-abuse by construction: thresholds, one counted visit per day, pass/lost/exempt exclusions, a redeeming visit does not count, reversal arithmetic that cannot mint rewards.
- Operators see progress at check-in and can choose to redeem (or skip) at check-out.
- Admin report and manual correction, all audited.

**Non-Goals**: see `proposal.md`.

## Decisions

1. **Bookkeeping in a trigger, the discount in the hook.** Accrual and redemption happen in `trg_loyalty_session_closed` (`after update of status on parking_sessions`, `open -> closed`); the amount reduction comes from `fare_reward_step` called by `fare_quote`. `check_out` stays at 11 arguments and is not re-declared by this change (a second re-declaration after merchants would multiply the merge risk). The trigger never raises: any exception is caught, a `skipped` visit with reason `error` is written and a warning is logged, because a loyalty bug must never block a customer from leaving.
2. **Reward value is snapshotted when earned.** `loyalty_rewards` stores `kind`, `max_amount` and `fixed_amount` at earn time, so an admin raising the value later does not inflate old rewards and lowering it does not cheat customers. Settings changes of N apply from the next counted visit (progress is a counter, it is not recomputed from history).
3. **Progress is a counter, the ledger is the audit.** `loyalty_accounts.progress` (0..N-1) is maintained incrementally under `pg_advisory_xact_lock(hashtext('loyalty:' || lot || ':' || plate))`. A visit that reaches N creates the reward and resets progress to 0. `loyalty_visits` explains every number (`progress_before`, `status`, skip reason, `earned_reward_id`).
4. **Redemption choice is a separate RPC, not a `check_out` parameter.** `choose_loyalty_redemption(p_session_id, p_choice)` stores `parking_sessions.loyalty_choice` (`redeem|skip|null`). In `auto` mode the reward applies unless `skip`; in `operator` mode it applies only when `redeem`. The preview (`check_out_preview`, through `fare_quote`) reports `reward.available`, `reward.applied` and `reward.reason`, so the dialog can render the switch and the amount before the operator confirms.
5. **A reward never subsidises an online payment already made.** If the session has `online_paid_amount > 0` (`add-online-payments`), the reward value is capped to `greatest(R - online_paid_amount, 0)`; with a zero result it is skipped and stays available (no refunds exist, rule A.9).
6. **One reward per session, oldest first.** Rewards are consumed `order by created_at, id` among `available` rows with `expires_at > now()`. `now()` (not the replayed exit instant) is used for expiry because the hook has no exit time argument; an offline replay of a check-out made before expiry but synced after it loses the reward (documented trade-off, open question 5).
7. **No customer surface.** Plate plus visit history is personal data (a plate identifies a vehicle owner). Nothing is exposed to `anon`; the customer only sees the receipt the operator hands over. Operators read progress through a definer RPC that returns counts only; the tables are admin-readable.
8. **Online only.** Settings, status, choice, adjustments and reports need the server. They are never queued in the outbox and add no Hive adapter.

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

How loyalty implements steps 5 and 9 (value computation, `fare_reward_step`):

- `free_stay`: `value = R` when `reward.max_amount is null`, else `min(R, max_amount)`.
- `fixed_amount`: `value = min(R, fixed_amount)`.
- Online cap (decision 5), then `a = min(value, R)`; `a = 0` returns no line.
- The loyalty trigger counts a visit from the stored result: a session whose `fare_adjustments` contains a `reward` line is a redeeming visit and does not count.

## Data model

```sql
alter table public.parking_settings
    add column if not exists loyalty_enabled boolean not null default false,
    add column if not exists loyalty_visits_required integer not null default 5,
    add column if not exists loyalty_reward_kind text not null default 'free_stay',
    add column if not exists loyalty_reward_max_amount integer,
    add column if not exists loyalty_reward_fixed_amount integer not null default 0,
    add column if not exists loyalty_min_amount integer not null default 0,
    add column if not exists loyalty_min_minutes integer not null default 0,
    add column if not exists loyalty_redeem_mode text not null default 'auto',
    add column if not exists loyalty_stack_with_merchant boolean not null default true,
    add column if not exists loyalty_reward_valid_days integer not null default 90;
alter table public.parking_settings drop constraint if exists parking_settings_loyalty_check;
alter table public.parking_settings add constraint parking_settings_loyalty_check check (
    loyalty_visits_required between 2 and 50
    and loyalty_reward_kind in ('free_stay', 'fixed_amount')
    and (loyalty_reward_max_amount is null or loyalty_reward_max_amount > 0)
    and loyalty_reward_fixed_amount >= 0
    and (loyalty_reward_kind <> 'fixed_amount' or loyalty_reward_fixed_amount > 0)
    and loyalty_min_amount >= 0
    and loyalty_min_minutes between 0 and 1440
    and loyalty_redeem_mode in ('auto', 'operator')
    and loyalty_reward_valid_days between 7 and 730);

alter table public.parking_sessions
    add column if not exists loyalty_choice text
        check (loyalty_choice in ('redeem', 'skip'));

create table if not exists public.loyalty_accounts (
    id               bigserial   primary key,
    lot_id           integer     not null references public.parking_lots(id),
    plate            varchar(20) not null,
    progress         integer     not null default 0 check (progress >= 0),
    earned_total     integer     not null default 0 check (earned_total >= 0),
    redeemed_total   integer     not null default 0 check (redeemed_total >= 0),
    last_counted_day date,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    unique (lot_id, plate)
);

create table if not exists public.loyalty_rewards (
    id                  bigserial   primary key,
    lot_id              integer     not null references public.parking_lots(id),
    plate               varchar(20) not null,
    status              text        not null default 'available'
                        check (status in ('available', 'redeemed', 'expired', 'reversed')),
    kind                text        not null check (kind in ('free_stay', 'fixed_amount')),
    max_amount          integer     check (max_amount is null or max_amount > 0),
    fixed_amount        integer     not null default 0 check (fixed_amount >= 0),
    visits_required     integer     not null check (visits_required >= 2),
    earned_session_id   integer     references public.parking_sessions(id) on delete set null,
    redeemed_session_id integer     references public.parking_sessions(id) on delete set null,
    redeemed_amount     integer     check (redeemed_amount is null or redeemed_amount >= 0),
    expires_at          timestamptz not null,
    created_at          timestamptz not null default now(),
    redeemed_at         timestamptz,
    constraint loyalty_rewards_redeemed_check check (
        (status = 'redeemed') = (redeemed_session_id is not null and redeemed_at is not null))
);
create index if not exists ix_loyalty_rewards_plate_open
    on public.loyalty_rewards (lot_id, plate, created_at, id) where status = 'available';
create index if not exists ix_loyalty_rewards_expiry
    on public.loyalty_rewards (expires_at) where status = 'available';

create table if not exists public.loyalty_visits (
    id               bigserial   primary key,
    lot_id           integer     not null references public.parking_lots(id),
    plate            varchar(20) not null,
    session_id       integer     not null unique references public.parking_sessions(id) on delete cascade,
    business_day     date        not null,
    status           text        not null check (status in ('counted', 'skipped', 'reversed')),
    skip_reason      text        check (skip_reason in (
        'pass', 'lost_ticket', 'exempt', 'below_amount', 'below_minutes',
        'same_day', 'reward_redeemed', 'error')),
    amount           integer     not null default 0,
    progress_before  integer     not null default 0,
    earned_reward_id bigint      references public.loyalty_rewards(id) on delete set null,
    created_at       timestamptz not null default now(),
    reversed_at      timestamptz,
    reverse_reason   text,
    constraint loyalty_visits_skip_check check ((status = 'skipped') = (skip_reason is not null)
        or status = 'reversed')
);
create index if not exists ix_loyalty_visits_plate_day
    on public.loyalty_visits (lot_id, plate, business_day) where status = 'counted';
create index if not exists ix_loyalty_visits_created on public.loyalty_visits (lot_id, created_at);

create table if not exists public.loyalty_adjustments (
    id         bigserial   primary key,
    lot_id     integer     not null references public.parking_lots(id),
    plate      varchar(20) not null,
    delta      integer     not null check (delta <> 0 and delta between -50 and 50),
    reason     varchar(200) not null check (length(btrim(reason)) between 3 and 200),
    actor_id   integer     references public.users(id) on delete set null,
    progress_after integer not null,
    created_at timestamptz not null default now()
);

alter table public.loyalty_accounts enable row level security;
alter table public.loyalty_rewards enable row level security;
alter table public.loyalty_visits enable row level security;
alter table public.loyalty_adjustments enable row level security;
revoke all on public.loyalty_accounts, public.loyalty_rewards,
    public.loyalty_visits, public.loyalty_adjustments from anon, authenticated;
grant select on public.loyalty_accounts, public.loyalty_rewards,
    public.loyalty_visits, public.loyalty_adjustments to authenticated;

-- One policy per table (replace the table name); admin of the ACTIVE lot only.
drop policy if exists loyalty_accounts_read on public.loyalty_accounts;
create policy loyalty_accounts_read on public.loyalty_accounts
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));
-- same text for loyalty_rewards_read, loyalty_visits_read, loyalty_adjustments_read

-- Audit (actor from auth.uid()); accounts and visits are ledgers and not audited twice.
drop trigger if exists trg_audit_row on public.loyalty_rewards;
create trigger trg_audit_row after insert or update or delete
    on public.loyalty_rewards for each row execute function public.record_audit();
drop trigger if exists trg_audit_row on public.loyalty_adjustments;
create trigger trg_audit_row after insert or update or delete
    on public.loyalty_adjustments for each row execute function public.record_audit();
```

The existing suite asserts RLS is enabled on every public table; all four comply. Anon has no grant (a test asserts `insufficient_privilege`). Operators cannot select the tables (policy needs lot admin); they use `loyalty_plate_status`. Every write is inside a `security definer` function that stamps `lot_id` explicitly. `lot_id` is `not null` on every table (AGENTS section 5). Versioned set: none of these tables joins `row_version_guard` (they are never edited offline); the new `parking_settings` columns join the existing versioned row automatically.

Plate helper:

```sql
create or replace function public.loyalty_norm_plate(p_plate text) returns text
language sql immutable set search_path = public
as $$ select upper(regexp_replace(coalesce(p_plate, ''), '\s', '', 'g')) $$;
revoke all on function public.loyalty_norm_plate(text) from public, anon, authenticated;
```

## RPC signatures

All `language plpgsql`, `security definer`, `set search_path = public`. Typed errors are `raise exception '<Name>Error'` (PostgREST message equals the name, mapped by `mapSupabaseError`). No existing RPC gets a parameter (no overload trap); every function below is NEW except `fare_reward_step`, which is replaced with the same signature.

| Function | Grants | Notes |
|---|---|---|
| `fare_reward_step(p_session_id integer, p_running integer, p_merchant_total integer) returns jsonb` (stable) | none (internal; keep the revoke from `public, anon, authenticated` that merchants applied) | replaces the no-op; contract shape of the shared contract |
| `loyalty_plate_status(p_plate text) returns jsonb` (stable) | authenticated | `require_app_user()`; lot = `current_lot_id()` |
| `get_loyalty_settings() returns jsonb` (stable) | authenticated | `require_lot_admin()` |
| `set_loyalty_settings(p_settings jsonb) returns jsonb` | authenticated | `require_lot_admin()`; only keys present are applied; invalid values raise `InvalidLoyaltySettingsError` |
| `choose_loyalty_redemption(p_session_id integer, p_choice text) returns jsonb` | authenticated | `p_choice` in `redeem`, `skip`, `auto` (`auto` clears the choice) |
| `adjust_loyalty_progress(p_plate text, p_delta integer, p_reason text) returns jsonb` | authenticated | `require_lot_admin()` |
| `list_loyalty_accounts(p_search text default null, p_limit integer default 50) returns jsonb` (stable) | authenticated | `require_lot_admin()`; second migration |
| `report_loyalty(p_start_date date, p_end_date date) returns jsonb` (stable) | authenticated | `require_lot_admin()`; second migration |
| `loyalty_reverse_visit(p_session_id integer) returns jsonb` | none (internal) | `revoke all ... from public, anon, authenticated`; called by a future void feature or by hand as `postgres` |
| `loyalty_on_session_closed() returns trigger` | none (trigger) | `security definer`; never raises |
| `loyalty_expire_rewards() returns integer` | service_role | job; `revoke all ... from public, anon, authenticated; grant execute ... to service_role` |

### Return shapes

`loyalty_plate_status`: `{"enabled": bool, "plate": text, "visits": int, "required": int, "next_visit": int, "reward_count": int, "reward_expires_at": timestamptz|null, "redeem_mode": "auto"|"operator", "counted_today": bool}`. `visits` is `progress`; `next_visit = progress + 1` (the "4" in "visit 4 of 5"); `reward_count` is the number of `available` non-expired rewards; `reward_expires_at` is the soonest. When the program is off: `{"enabled": false}` and nothing else (the chip is hidden). A plate with no account answers `visits: 0`, `reward_count: 0` without creating the account (accounts are created lazily by the trigger).

`get_loyalty_settings` / `set_loyalty_settings`: `{"enabled": bool, "visits_required": int, "reward_kind": text, "reward_max_amount": int|null, "reward_fixed_amount": int, "min_amount": int, "min_minutes": int, "redeem_mode": text, "stack_with_merchant": bool, "reward_valid_days": int}`. `set_loyalty_settings` accepts the same keys.

`choose_loyalty_redemption`: `{"session_id": int, "choice": "redeem"|"skip"|null, "reward_available": bool}`.

`adjust_loyalty_progress`: `{"plate": text, "progress": int, "required": int, "delta": int}`.

`loyalty_reverse_visit`: `{"reversed": bool, "reward_reversed": bool, "reward_restored": bool, "progress": int|null}`.

`list_loyalty_accounts`: `[{"plate": text, "progress": int, "earned_total": int, "redeemed_total": int, "reward_count": int, "last_counted_day": date|null}]` newest `updated_at` first, `p_limit` clamped to 1..200, `p_search` matches `loyalty_norm_plate(p_search)` as a prefix.

`report_loyalty`:

```json
{
  "start_date": "2026-11-01", "end_date": "2026-11-30", "enabled": true,
  "members": 128, "active_members": 57,
  "visits": {"counted": 410, "skipped": 96, "reversed": 2,
             "skipped_by_reason": [{"reason": "same_day", "count": 40}]},
  "rewards": {"earned": 81, "redeemed": 63, "expired": 4, "reversed": 1, "available": 30},
  "discount_given": 189000,
  "top_plates": [{"plate": "ABC123", "counted": 9, "redeemed": 1, "discount": 12000}]
}
```

`members` = accounts with `created_at <= end of range`; `active_members` = distinct plates with a counted visit in range; visit figures count `loyalty_visits.created_at` in the range; the reward filters are normative in the `report_loyalty` algorithm below; `available` is a point-in-time count; `discount_given` is `sum(redeemed_amount)` of rewards redeemed in range; `top_plates` up to 10 ordered by `counted desc, plate`.

### Typed errors (new unless marked existing)

`LoyaltyDisabledError` (choose/adjust while `loyalty_enabled = false`), `InvalidLoyaltySettingsError`, `InvalidLoyaltyChoiceError`, `NoRewardAvailableError` (`redeem` with no available reward), `LoyaltyReasonRequiredError`, `LoyaltyAdjustRangeError`, `LoyaltyAccountNotFoundError` (adjust on a plate without account). Existing and reused: `InvalidPlateError`, `SessionNotFoundError`, `SessionAlreadyClosedError`, `LotRequiredError`, `AdminRequiredError`, `InvalidTokenError`, `InvalidReportRangeError`.

### Function algorithms (normative steps)

**`fare_reward_step(p_session_id, p_running, p_merchant_total)`**: (1) load the session and `parking_settings` of its lot; if the program is off or `p_running <= 0` return `{"amount": 0, "line": null, "info": null}`. (2) plate from `vehicles`; progress from the account (0 when none). (3) pick the reward: `status = 'available' and expires_at > now()` ordered `created_at, id` limit 1; none returns `{"amount": 0, "line": null, "info": {"available": false, "applied": false, "mode": <mode>, "progress": {"visits": <p>, "required": <N>}, "reason": "none"}}`. (4) decide by mode and `loyalty_choice`: `auto` applies unless the choice is `skip` (reason `skipped`); `operator` applies only when the choice is `redeem` (reason `operator_choice_pending` when null, `skipped` when `skip`). (5) `stack_with_merchant = false and p_merchant_total > 0` gives reason `merchant`. (6) value per the rules above and the online cap (reason `zero` when `a = 0`). (7) when applied return `{"amount": a, "line": {"type": "reward", "ref_id": <reward id>, "label": "loyalty", "kind": <reward kind>, "amount": a}, "info": {"available": true, "applied": true, ...}}`; when not applied the info has `available: true, applied: false, reason: <reason>`. The function reads, never writes, so the preview has no side effect.

**`loyalty_on_session_closed()`** (row trigger `trg_loyalty_session_closed`, `after update of status on public.parking_sessions for each row when (old.status = 'open' and new.status = 'closed')`):
1. Load settings of `new.lot_id`; program off returns `new` (before anything is written).
2. `plate := vehicles.plate`; take `pg_advisory_xact_lock(hashtext('loyalty:' || lot || ':' || plate))`; upsert the account (`insert ... on conflict (lot_id, plate) do nothing`, then `select ... for update`).
3. Redemption: for each element of `new.fare_adjustments` with `type = 'reward'`, `update loyalty_rewards set status = 'redeemed', redeemed_session_id = new.id, redeemed_at = now(), redeemed_amount = <line amount> where id = <ref_id> and lot_id = new.lot_id and status = 'available'`; `redeemed := true` when a row changed; account `redeemed_total += 1`.
4. Qualification, first failing rule wins and is stored as `skip_reason`: `redeemed` (any reward line) is `reward_redeemed`; `new.payment_method = 'monthly_pass'` is `pass`; `new.lost_ticket` is `lost_ticket`; `new.payment_method = 'exempt'` is `exempt`; `new.amount_charged < loyalty_min_amount` (or null) is `below_amount`; `exit_time - entry_time < loyalty_min_minutes minutes` is `below_minutes`; a `counted` visit of the same plate and `business_day` (`(new.exit_time at time zone tz)::date`, `tz = coalesce(business_timezone, 'America/Bogota')`) is `same_day`. The amount rule is `amount_charged > 0 and amount_charged >= loyalty_min_amount`, otherwise `below_amount`: a zero charge (for example a 100 % merchant benefit) never counts, even with `loyalty_min_amount = 0`.
5. Insert `loyalty_visits` (`on conflict (session_id) do nothing`) with `progress_before = account.progress`.
6. When counted: `progress := progress + 1`, `last_counted_day := business_day`; when `progress >= loyalty_visits_required`: insert the reward (snapshot kind/max/fixed, `visits_required`, `earned_session_id`, `expires_at = now() + make_interval(days => loyalty_reward_valid_days)`), set the visit's `earned_reward_id`, `progress := 0`, `earned_total += 1`.
7. `exception when others` around steps 2-6: insert a `skipped`/`error` visit (itself guarded) and `raise warning 'loyalty_on_session_closed: %', sqlerrm`; return `new`.

**`loyalty_reverse_visit(p_session_id)`**: lock the plate key; no `counted`/`skipped` visit row, or a `reversed` one, returns `reversed: false`. (a) If this session redeemed a reward (`loyalty_rewards.redeemed_session_id = p_session_id`) and the reward `expires_at > now()`: status `available`, clear the redemption fields, `redeemed_total -= 1`, `reward_restored = true`; past expiry it becomes `expired`. (b) If the visit was `counted`: set it `reversed` (`reversed_at = now()`, reason `void`); when it earned a reward: reward `available` becomes `reversed`, `earned_total -= 1`, `progress := visits_required - 1` (the visit that earned it is undone, the customer is one short again); reward already `redeemed` is KEPT and `progress` is unchanged (no clawback of a benefit already given); a visit that earned nothing sets `progress := greatest(progress - 1, 0)`. (c) A `skipped` visit becomes `reversed` with no counter change. (d) `last_counted_day := (select max(business_day) from loyalty_visits where status = 'counted' ...)`. Reversal never creates a reward.

**`adjust_loyalty_progress`**: `require_lot_admin()`; program off `LoyaltyDisabledError`; plate must match `^[A-Z0-9-]{3,20}$` after `loyalty_norm_plate` else `InvalidPlateError`; reason trimmed 3..200 else `LoyaltyReasonRequiredError`; account missing `LoyaltyAccountNotFoundError`; `progress + p_delta` outside `0 .. visits_required - 1` raises `LoyaltyAdjustRangeError` (a manual correction never mints a reward); insert `loyalty_adjustments`; return the shape.

**`choose_loyalty_redemption`**: `require_app_user()`; program off `LoyaltyDisabledError`; `p_choice` not in (`redeem`,`skip`,`auto`) `InvalidLoyaltyChoiceError`; session by id (`SessionNotFoundError`), `closed` `SessionAlreadyClosedError`, `lot_id <> current_lot_id()` `LotRequiredError`; `redeem` with no available non-expired reward for the plate `NoRewardAvailableError`; `update parking_sessions set loyalty_choice = ...` (`auto` stores null).

**`loyalty_expire_rewards`**: `update loyalty_rewards set status = 'expired' where status = 'available' and expires_at <= now()`; returns the row count.

**`report_loyalty`** (second migration): `require_lot_admin()`, `p_start_date <= p_end_date` and a span of at most 366 days else `InvalidReportRangeError`; window `[start 00:00, end + 1 day 00:00)` in the lot timezone (`coalesce(business_timezone, 'America/Bogota')`); filters: visits by `loyalty_visits.created_at`, rewards earned by `created_at`, redeemed by `redeemed_at`, expired/reversed by `created_at` of rewards in that status.

### Triggers

| Trigger | Table / event | Condition | Action |
|---|---|---|---|
| `trg_loyalty_session_closed` | `parking_sessions` after update of `status` | `old.status = 'open' and new.status = 'closed'` | `loyalty_on_session_closed()` |

## State machines

Reward: `available` -> `redeemed` (closing session carries its line) | `expired` (job or reversal past expiry) | `reversed` (earning visit undone while still available). `redeemed` -> `available` only through `loyalty_reverse_visit` of the redeeming session (before expiry). Terminal: `expired`, `reversed`.

Visit: `counted` | `skipped(reason)` -> `reversed` (never back).

Account progress: `0 -> 1 -> ... -> N-1 -> (reward earned) 0`; reversal and manual adjustment move it inside `0..N-1`.

Redemption choice on an open session: `null (auto) <-> redeem <-> skip`, cleared when the session closes (the column is kept as the audit of what the operator chose).

## Flutter

New feature `lib/features/loyalty/`:

```text
lib/features/loyalty/
  domain/entities/loyalty_status.dart            # LoyaltyStatus
  domain/entities/loyalty_settings.dart          # LoyaltySettings, enums
  domain/entities/loyalty_account.dart           # LoyaltyAccount
  domain/entities/loyalty_report.dart            # LoyaltyReport, LoyaltyTopPlate, SkipCount
  domain/repositories/loyalty_repository.dart    # port
  application/loyalty_status_cubit.dart          # check-in chip and receipt progress
  application/loyalty_admin_cubit.dart           # /loyalty page
  infrastructure/loyalty_remote_data_source.dart
  infrastructure/loyalty_repository_impl.dart
  presentation/loyalty_page.dart                 # tabs: Program, Members, Report
  presentation/loyalty_settings_form.dart
  presentation/loyalty_report_section.dart
  presentation/loyalty_progress_chip.dart        # "Visita 4 de 5" / reward badge
  presentation/loyalty_report_csv.dart           # loyaltyReportCsv(...)
  presentation/loyalty_report_pdf.dart           # buildLoyaltyReportPdf(...)
lib/app/di/modules/loyalty_module.dart           # NEW
lib/app/router/deferred/loyalty_entry.dart       # NEW
```

Entities (Equatable; `fromJson(Map<String, dynamic>)` on the entity, like `PublicReservation.fromJson`):

- `LoyaltyStatus {bool enabled, String plate, int visits, int required, int nextVisit, int rewardCount, DateTime? rewardExpiresAt, LoyaltyRedeemMode redeemMode, bool countedToday}` with `static const LoyaltyStatus disabled`, `bool get hasReward => rewardCount > 0`, `bool get earnsRewardNow => enabled && nextVisit >= required` (the visit being registered is the last one needed). Missing keys parse as zeros and `enabled: false` (an older database still parses).
- `enum LoyaltyRedeemMode { auto, operator }`, `enum LoyaltyRewardKind { freeStay, fixedAmount }` with `static parse(String)` (unknown falls back to `auto` / `freeStay`).
- `LoyaltySettings {bool enabled, int visitsRequired, LoyaltyRewardKind rewardKind, int? rewardMaxAmount, int rewardFixedAmount, int minAmount, int minMinutes, LoyaltyRedeemMode redeemMode, bool stackWithMerchant, int rewardValidDays}`; `toJson()` returns the `set_loyalty_settings` keys (explicit `reward_max_amount: null` when no cap).
- `LoyaltyAccount {String plate, int progress, int earnedTotal, int redeemedTotal, int rewardCount, DateTime? lastCountedDay}`.
- `LoyaltyReport {DateTime startDate, DateTime endDate, bool enabled, int members, int activeMembers, int counted, int skipped, int reversed, List<SkipCount> skippedByReason, int earned, int redeemed, int expired, int rewardsReversed, int available, int discountGiven, List<LoyaltyTopPlate> topPlates}` with `static empty`.

Port:

```dart
abstract class LoyaltyRepository {                     // all online only
  Future<LoyaltyStatus> status(String plate);          // loyalty_plate_status
  Future<LoyaltySettings> loadSettings();              // get_loyalty_settings
  Future<LoyaltySettings> saveSettings(LoyaltySettings settings); // set_loyalty_settings
  Future<void> choose({required int sessionId, required LoyaltyChoice choice}); // choose_loyalty_redemption
  Future<List<LoyaltyAccount>> accounts({String? search});         // list_loyalty_accounts
  Future<LoyaltyAdjustResult> adjust({required String plate, required int delta, required String reason});
  Future<LoyaltyReport> report({required DateTime start, required DateTime end}); // report_loyalty
}
enum LoyaltyChoice { redeem, skip, auto }
```

`SupabaseLoyaltyRemoteDataSource` calls each RPC by name with `p_*` named params and wraps every call in `try { ... } catch (error) { throw mapSupabaseError(error); }`. Nothing uses `SyncOutbox`; no `MutationEntity` value, no Hive adapter.

Cubits (extend `ResilientCubit`, sealed `Equatable` states, the four UI states):

- `LoyaltyStatusCubit`: `LoyaltyStatusIdle` (hidden: nothing typed, program off or offline), `LoyaltyStatusLoading` (skeleton chip), `LoyaltyStatusReady(status)` (chip, or reward badge), `LoyaltyStatusFailure(message, {failure})` (a small text with a retry button; never blocks check-in). Methods: `load(String plate)` (ignores plates shorter than 3 characters, drops stale answers when the plate changed), `clear()`. `NetworkFailure` emits `Idle` (offline shows nothing).
- `LoyaltyAdminCubit`: `LoyaltyAdminInitial`, `LoyaltyAdminLoading` (skeleton), `LoyaltyAdminLoaded(settings, accounts, report?, {Submission submission})` (an empty `accounts` list renders the empty state with the CTA "Enable the program" when `settings.enabled` is false), `LoyaltyAdminFailure(message, {failure})` (retry). Methods: `load()`, `save(LoyaltySettings)`, `search(String)`, `adjust(plate, delta, reason)`, `loadReport(start, end)`. Actions reuse `Submission` from `core/state/submission.dart`.

Widgets reused by name: `SectionHeader`, `MetricCard`, `EmptyState`, `ErrorState`, `StatusChip`, `SkeletonList`, `AppIconButton`, `ConfirmDialog`, `PlateText`, `PlateInputField`, `FilterBar`, `MoneyText`, `AsyncView`. No colors outside `Theme.of(context)` (`StatusColors.success` for the reward badge); every target at least `Layout.minTouch`; money only through `Money`.

Integration points (verified file names):

- Route `/loyalty`: `GoRoute(path: 'loyalty', ...)` under home in `lib/app/router/app_router.dart`, deferred like `reports` through `lib/app/router/deferred/loyalty_entry.dart` (`buildLoyaltyEntry()` provides `LoyaltyAdminCubit`). Admin-only by default (`operatorRoutes` in `lib/app/router/route_access.dart` is an allowlist and is NOT changed). Nav entry in `lib/app/shell/app_destinations.dart` management list (icon `Icons.loyalty_outlined`, selected `Icons.loyalty`).
- Check-in (`lib/features/check_in/presentation/check_in_page.dart`): when the plate field holds a valid plate and the device is online, a `LoyaltyProgressChip` renders under the vehicle card from `LoyaltyStatusCubit` (provided where the page is built in `app_router.dart`; guarded by `serviceLocator.isRegistered<LoyaltyRepository>()` in tests). Text "Visita 4 de 5", with the reward badge "Recompensa disponible" when `hasReward`. After a successful online check-in the receipt dialog receives the last `Ready` status.
- Check-out (`lib/features/check_out/presentation/payment_method_dialog.dart`): reads `quote.reward` from the preview (the preview embeds the `fare_quote` result owned by merchants; verify the key against `add-merchant-validations` design when implementing). `reward.available && !reward.applied && reward.reason == 'operator_choice_pending'` shows a switch "Usar recompensa"; `reward.applied` in auto mode shows the line with a "No usar ahora" text button. Either calls `LoyaltyRepository.choose(...)` and re-requests the preview before enabling the confirm button. After a successful online check-out the page asks `LoyaltyStatusCubit.load(plate)` to put "Visita n de N" / "Recompensa ganada" on the receipt.
- Receipt: `ReceiptData` (`lib/core/receipt/receipt_data.dart`) gains optional `loyaltyVisits:int?`, `loyaltyRequired:int?`, `loyaltyRewardEarned:bool = false` (additive; defaults keep every call site and test valid); `ReceiptCard` (`lib/core/widgets/receipt_card.dart`), `EscPosGenerator` and the PDF printer (`lib/features/receipt_printing/infrastructure/`) print one line when `loyaltyRequired != null`. The reward fare line itself is rendered by the generic adjustment lines of `add-merchant-validations` (`type == 'reward'` maps to the label `receiptLoyaltyReward`). Pending-sync receipts print no loyalty line (security test in the existing receipt tests).
- DI: `registerLoyaltyModule(GetIt sl)` registers `LoyaltyRemoteDataSource` and `LoyaltyRepository` (lazy singletons over `sl<SupabaseClient>()`), `LoyaltyStatusCubit` and `LoyaltyAdminCubit` (factories); called from `lib/app/di/injection.dart` next to `registerWaitlistModule`.
- Failure texts: the new typed names go into `lib/core/l10n/failure_messages.dart` `_byCode`.
- Reports: the loyalty report lives on `/loyalty`, not in `ReportsCubit` (`lib/features/reports` is untouched); CSV is a function like `reportCsv` (raw integers, columns `section,label,value`) copied to the clipboard, PDF built like `report_pdf.dart` and shared with `lib/core/receipt/pdf_share.dart`.

## l10n (add to both ARB files, regenerate with `flutter gen-l10n`)

| Key | ES | EN |
|---|---|---|
| `loyaltyTitle` | Fidelización | Loyalty |
| `loyaltyTabProgram` | Programa | Program |
| `loyaltyTabMembers` | Clientes | Members |
| `loyaltyTabReport` | Reporte | Report |
| `loyaltyEnabled` | Programa activo | Program enabled |
| `loyaltyVisitsRequired` | Visitas para ganar | Visits to earn |
| `loyaltyRewardKind` | Tipo de recompensa | Reward type |
| `loyaltyKindFreeStay` | Estadía gratis | Free stay |
| `loyaltyKindFixed` | Descuento fijo | Fixed discount |
| `loyaltyRewardMax` | Tope de la estadía gratis | Free stay cap |
| `loyaltyRewardFixed` | Valor del descuento | Discount value |
| `loyaltyMinAmount` | Pago mínimo por visita | Minimum paid per visit |
| `loyaltyMinMinutes` | Minutos mínimos por visita | Minimum minutes per visit |
| `loyaltyRedeemMode` | Canje | Redemption |
| `loyaltyModeAuto` | Automático | Automatic |
| `loyaltyModeOperator` | Lo decide el operador | Operator decides |
| `loyaltyStackMerchant` | Acumular con convenios | Combine with merchant benefits |
| `loyaltyValidDays` | Vigencia de la recompensa (días) | Reward validity (days) |
| `loyaltySave` | Guardar programa | Save program |
| `loyaltySaved` | Programa guardado | Program saved |
| `loyaltyVisitOf` | Visita {current} de {total} | Visit {current} of {total} |
| `loyaltyRewardAvailable` | Recompensa disponible | Reward available |
| `loyaltyRewardEarned` | ¡Recompensa ganada! | Reward earned! |
| `loyaltyUseReward` | Usar recompensa | Use reward |
| `loyaltyDontUseNow` | No usar ahora | Do not use now |
| `loyaltyRewardLine` | Recompensa de fidelidad | Loyalty reward |
| `loyaltyRewardExpires` | Vence el {date} | Expires {date} |
| `loyaltyMembersEmpty` | Aún no hay clientes con visitas | No members with visits yet |
| `loyaltyEnableCta` | Activar el programa | Enable the program |
| `loyaltySearchPlate` | Buscar placa | Search plate |
| `loyaltyAdjust` | Corregir progreso | Adjust progress |
| `loyaltyAdjustDelta` | Cambio (+/-) | Change (+/-) |
| `loyaltyAdjustReason` | Motivo (obligatorio) | Reason (required) |
| `loyaltyReportMembers` | Clientes | Members |
| `loyaltyReportCounted` | Visitas contadas | Counted visits |
| `loyaltyReportSkipped` | Visitas no contadas | Skipped visits |
| `loyaltyReportEarned` | Recompensas ganadas | Rewards earned |
| `loyaltyReportRedeemed` | Recompensas canjeadas | Rewards redeemed |
| `loyaltyReportDiscount` | Descuento otorgado | Discount given |
| `loyaltyReportTopPlates` | Placas frecuentes | Top plates |
| `loyaltySkip_pass` | Pase mensual | Monthly pass |
| `loyaltySkip_lost_ticket` | Ticket perdido | Lost ticket |
| `loyaltySkip_exempt` | Exento | Exempt |
| `loyaltySkip_below_amount` | Pago bajo el mínimo | Below minimum paid |
| `loyaltySkip_below_minutes` | Estadía muy corta | Stay too short |
| `loyaltySkip_same_day` | Ya contó hoy | Already counted today |
| `loyaltySkip_reward_redeemed` | Usó recompensa | Used a reward |
| `loyaltySkip_error` | Error interno | Internal error |
| `errorLoyaltyDisabled` | El programa de fidelización está desactivado | The loyalty program is disabled |
| `errorLoyaltySettings` | Revisa los valores del programa | Check the program values |
| `errorLoyaltyChoice` | Opción de canje no válida | Invalid redemption option |
| `errorNoRewardAvailable` | Esta placa no tiene recompensa disponible | This plate has no reward available |
| `errorLoyaltyReason` | Escribe un motivo de 3 a 200 caracteres | Write a reason of 3 to 200 characters |
| `errorLoyaltyAdjustRange` | El ajuste dejaría el progreso fuera de rango | The adjustment would leave progress out of range |
| `errorLoyaltyAccountNotFound` | Esa placa no tiene cuenta de fidelización | That plate has no loyalty account |

## Offline behaviour

Everything new is online only: status chip, redemption choice, settings, adjustments and report show nothing or an error with retry when offline (`NetworkFailure`); nothing is queued in the outbox (AGENTS section 5: money-adjacent admin actions are not queued).

A queued check-out replays with `client_exit_time` (at most 12 hours old, else `StaleExitTimeError`). At replay the server computes `fare_quote(session, exit_at)`; the reward hook uses the session's `loyalty_choice` as stored (an offline operator cannot choose, so in `operator` mode no reward is applied to an offline exit and the reward stays `available`; in `auto` mode it is applied), the reward expiry is judged at replay `now()` (decision 6), and the loyalty trigger runs when the replay closes the session, with the business day computed from the replayed `exit_time` in the lot timezone. A queued check-in is untouched. The offline receipt carries no loyalty line.

## Security analysis

| Actor | Can | Cannot |
|---|---|---|
| anon | nothing (no table grant, no function grant, no public page) | read or call any loyalty object |
| authenticated operator (active lot) | `loyalty_plate_status`, `choose_loyalty_redemption` for open sessions of its lot, close sessions that carry rewards | select the four tables, read or change settings, adjust progress, run the report (`AdminRequiredError`), other lots (`LotRequiredError`) |
| lot admin | everything an operator can + settings, adjustments, members list, report | other lots; mint a reward by adjustment |
| service_role / postgres | `loyalty_expire_rewards`; `loyalty_reverse_visit` as `postgres` | n/a |

- Lot isolation: every definer function stamps and filters `lot_id` explicitly; the table policies use `current_lot_id()` plus `is_lot_admin(lot_id)`. The accounts are per `(lot_id, plate)`: the same plate in lot 2 has an independent progress.
- Privacy: a plate plus visit counts is personal data. Operators get counts only and never the visit history; the audit log keeps the reason and the actor of every manual adjustment; no endpoint is anonymous. Retention follows the session retention (rows cascade with sessions on `loyalty_visits`; accounts and rewards persist: open question 6).
- Abuse: thresholds (`min_amount`, `min_minutes`), one counted visit per plate per day, zero-charge visits never count, pass/lost/exempt excluded, redeeming visit does not count, plate normalised before every lookup, and the trigger holds a per-plate advisory lock so two concurrent closes cannot double count. A manual adjustment is lot-admin only, bounded to `0..N-1`, and audited, so it cannot mint rewards.
- Operator fraud: an operator can close sessions for a regular's plate to farm visits only if real money (`amount_charged >= min_amount`) is recorded each time; `discount_rate` and `zero_charge` anomalies (`add-cash-anomaly-detection`) still apply to the cash side.
- The reward hook and the trigger are internal; `fare_reward_step` stays revoked from API roles.

## Worked fare examples

Fixtures: car, hourly 3000, nightly 2000 (22:00-06:00), daily cap 20000, `lost_ticket_fee` 15000, `America/Bogota`. N = 5, `loyalty_min_amount` 3000, `loyalty_min_minutes` 30 unless stated. All amounts are minor units.

1. **Midnight wrap, free stay, no cap** (F2): `23:00 Mon -> 02:00 Tue`, base 6000 (1 + 2 night hours), no pricing, no merchant. Reward `free_stay`, `max_amount` null: `a = min(6000, 6000) = 6000`, `R = 0`, `amount_due = 0`. The line is stored (`fare_adjustments = [{"type":"reward","amount":6000,...}]`, `gross_amount = 6000`): the zero charge is explained, no anomaly. The visit is `skipped(reward_redeemed)`; progress unchanged.
2. **Daily cap, fixed discount** (F3): `08:00 -> 18:00`, base `min(30000, 20000) = 20000`. Reward `fixed_amount` 5000: `a = min(5000, 20000) = 5000`, `amount_due = 15000`. The visit does not count (it redeemed).
3. **Free stay with a cap** (F4): `20:00 -> 23:30`, base 10000. Reward `free_stay` `max_amount` 8000: `a = min(8000, 10000) = 8000`, `amount_due = 2000`.
4. **Lost ticket** (F6): F1 stay, `gross = greatest(9000, 15000) = 15000`. Exclusion 2b: no reward even if `available` (info absent, reward stays `available`), `amount_due = 15000` (a manual discount of 1000 would give 14000). The visit is `skipped(lost_ticket)`.
5. **Pass holder** (F5): base 0, `amount_due = 0`, no reward, visit `skipped(pass)`, progress unchanged, reward stays `available`.
6. **Canonical stack** (F1): base 9000, pricing multiplier 12000 bps gives `G = 10800`; merchant 50 % gives `a = (10800 * 50 + 50) / 100 = 5400`, `R = 5400`; reward `fixed_amount` 2000 gives `a = 2000`, `R = 3400`; manual discount 400 gives `amount_due = 3000`. `gross_amount = 10800`, `fare_adjustments = [merchant 5400, reward 2000]`, `discount_amount = 400`. With `loyalty_stack_with_merchant = false` the reward is skipped (reason `merchant`) and stays `available`: `R = 5400`, `amount_due = 5000`.
7. **Floor, never below zero**: 1 h stay base 3000, merchant `fixed_amount` 5000 gives `a = 3000`, `R = 0`; the reward value is 0 so it is skipped (reason `zero`) and stays `available`; `amount_due = 0`; adjustments (3000) equal `gross_amount` so the zero charge is explained. The visit does not count (`below_amount`: zero never counts).
8. **Online payment already made**: F1 base 9000, customer paid 9000 online before leaving, reward fixed 2000: `value = min(2000, greatest(9000 - 9000, 0)) = 0`, skipped, stays `available`, charge stays 9000, and the visit counts (`amount_charged = 9000`). If the customer had paid only 6000 online, `value = min(2000, 3000) = 2000`, `R = 7000`, `amount_charged = greatest(7000, 6000) = 7000`, desk collects 1000.
9. **Accrual** (N = 5, progress 3, `min_amount` 3000, `min_minutes` 30): a 09:00-11:30 visit paying 9000 counts (progress 4); a second visit the same business day paying 9000 is `skipped(same_day)`; a 20-minute visit paying 3000 is `skipped(below_minutes)`; the next day a 1 h visit paying 3000 counts, reaching 5: reward created (`free_stay`, `expires_at = now() + 90 days`), progress 0, `earned_total` +1.

## Trade-offs and rejected alternatives

- **Re-declaring `check_out` to redeem and count**: rejected; it is the most contended function (online payments, merchants) and a third re-declaration multiplies merge risk. The trigger sees the final stored row.
- **A `p_redeem_reward` parameter on `check_out`**: rejected (overload trap, and offline replays could not carry a decision they never saw). A pre-call RPC keeps 11 arguments.
- **Recomputing progress from the ledger**: rejected; changing N would silently mint or revoke rewards. A counter with a ledger audit is predictable.
- **Points instead of visits**: rejected for scope; visits are what an operator can explain at the window.
- **A public progress page or WhatsApp message**: rejected here (plate privacy, enumeration of plates, WhatsApp template approval); listed as a follow-up.
- **Counting at check-in**: rejected; a visit is paid only when it closes.
- **Applying the reward through the manual discount**: rejected (admin-only, no ledger, no cap, no report).
- **Cross-lot accounts**: rejected; a plate can park anywhere and lots are separate businesses.

## Open questions for the owner

1. N, reward kind and cap defaults (5 visits, free stay up to what amount?) and whether `min_amount` should be the lot's one-hour fare.
2. Should a pass holder's days count toward visits (today: no, as asked)?
3. `auto` or `operator` as the recommended mode; `operator` adds a tap at the window.
4. Should rewards stack with merchant benefits (default yes; `loyalty_stack_with_merchant` turns it off)?
5. Reward expiry judged at replay time penalises an offline exit synced after expiry; accept, or pass the exit instant to the hook (needs a merchants signature change)?
6. Retention of `loyalty_accounts`/`loyalty_rewards` for plates inactive for N months (Ley 1581): purge job wanted?
7. The balance of a reward when a future void feature reverses a redeeming visit: restore it (this design) or burn it?
8. Is a daily commuter allowed one qualifying visit per day only (this design), or one per exit?
