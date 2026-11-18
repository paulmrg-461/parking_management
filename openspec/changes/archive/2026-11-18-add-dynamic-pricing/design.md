## Context

What exists today (verified in `supabase/migrations`):

- The fare is `fare_breakdown(p_category_id integer, p_entry_time timestamptz, p_exit_time timestamptz, p_has_pass boolean default false)` (latest `0072_billing_integrity.sql`): `ceil(stay / 1 h)` hours once for the whole stay, split over (calendar day, day|night) buckets by `allocate_billable_hours`, each calendar day capped at the daily tariff. `calculate_fare` (`0053`) is a wrapper. Tariffs are read from `tariffs` (`type in ('hourly','daily','nightly')`, `active`, one row per category/type; lot-checked by the composite FK of `0072`).
- `check_in` (latest `0098_reservation_grace_setting.sql`) has 11 parameters: `p_plate text, p_category_id integer default null, p_color text default null, p_brand text default null, p_photos jsonb default '[]', p_idempotency_key text default null, p_client_entry_time timestamptz default null, p_lot_id integer default null, p_left_keys boolean default false, p_spot_id integer default null, p_videos jsonb default '[]'`. It rejects `p_client_entry_time > now() + 5 min` (`InvalidEntryTimeError`), computes `entry_at := coalesce(p_client_entry_time, now())`, takes `pg_advisory_xact_lock(hashtext('group:' || lot || ':' || group))`, flips the plate's active hold to `used` BEFORE the insert (`update category_reservations set status = 'used' where plate = ... and status = 'active' and reserved_until + reservation_grace(lot) > now()`), and then `insert into public.parking_sessions (vehicle_id, operator_id, entry_time, status, lot_id, left_keys, spot_id)`. Its response JSON is built inside the function and carries no price. Adding a parameter would create an overload trap (`docs/agent-memory.md`), so this change does NOT touch `check_in`.
- `category_reservations` (`0021`, `lot_id` added by `0024`, `customer_name/customer_phone/source` by `0087/0088`): holds have no price; `source` is `app` (operator), `public` (the `/reserve` page) or `waitlist` (only if `add-booking-waitlist` is merged). A claimed waitlist offer flips to `source = 'public'`.
- `public_availability(p_lot_id integer)` (latest `0101_branding_cover.sql`) already ships `categories[].hourly_amount` (active hourly tariff, `0093`). The forecast change (`openspec/changes/add-occupancy-forecast`) renames this function to `public_availability_base` plus a wrapper; at the time of writing it has NOT landed (`grep -l public_availability_base supabase/migrations/*.sql` is empty).
- Occupancy sources: `capacity_snapshot()` (`0061`, `security definer`, header lot) counts open sessions and active holds per group (`car`, `moto`) against `car_capacity/moto_capacity` minus out-of-service (`usable_capacity`), or the number of active `parking_spots` of the group when bays are drawn. `category_group(p_name text)` maps a category name to `car|moto|heavy`; `heavy` has no capacity configuration, so its occupancy is unknown.
- `report_hourly_traffic(p_start_date date, p_end_date date)` (`0082`) is the admin view of entries/exits per local hour; the simulation and the admin screen reuse its idea (local hour via `parking_settings.business_timezone`).
- `parking_settings` is versioned (`0105`, `row_version_guard`) and audited (`record_audit`). `tariffs` is versioned too and is NOT touched.

The owner asked for surge-style prices ("hora pico", "noche valle", "evento") without ever surprising the customer: whatever rate is shown at the gate or on `/reserve` must be the rate used at check-out, even if the lot gets fuller or the rules change while the car is parked.

## Goals / Non-Goals

**Goals**

- Admin-defined rules per lot (vehicle group, occupancy band, weekday mask, local time window) that produce a multiplier and/or a flat surcharge, bounded by a lot floor and ceiling and a rounding step.
- The effective rate is LOCKED when the session is created (stored on `parking_sessions.pricing_lock`) and only that lock is used at check-out, preview, public QR page and reprint.
- A public-page hold carries its own lock; the session that consumes the hold never pays more than the hold promised.
- The current price is visible before committing: `/reserve` (anonymous), the check-in screen (operator) and the entry receipt.
- Monthly passes, lost tickets and every lot without the feature behave exactly as today.
- Audit trail for rules and settings; an admin "simulate" RPC to preview rules against the last N days of real sessions; a small report of the real impact.

**Non-Goals**

- Rule stacking (one winning rule per session; see Decisions).
- Changing tariffs, the night window, the daily cap or `fare_breakdown` (pricing wraps the result).
- Pricing monthly pass sales, lost-ticket fees or the manual discount.
- Per-minute repricing while the car is parked (the lock is the whole point).
- Forecast-based prices (needs `add-occupancy-forecast` data and is a later change).
- Online payment of a price different from the locked one (`add-online-payments` already pays the number the server computes).
- Offline editing of rules or settings: admin CRUD is online only through RPCs.

## Decisions

1. **The lock is a JSON snapshot on the session, written by a trigger.** `parking_sessions.pricing_lock jsonb` (null = identity, no pricing). A `BEFORE INSERT` trigger (`trg_parking_sessions_pricing_lock`) evaluates the rules for `new.entry_time` and writes the lock, so `check_in`, offline replays and any future insert path are covered without changing `check_in`'s 11-argument signature. The snapshot copies the rule's effect and the lot's floor, ceiling and rounding at lock time, so later edits to rules or settings can never change an open session. A second trigger makes the column immutable after insert (`PricingLockImmutableError`).
2. **Pricing is applied through the hook `fare_pricing_step`.** `add-merchant-validations` owns `fare_quote` and ships `fare_pricing_step(p_session_id integer, p_base integer) returns jsonb` as a no-op. This change replaces ONLY that function (`create or replace`, same signature). It never re-declares `fare_quote`, `check_out` or `check_out_preview`.
3. **Single winning rule.** Among the active rules of the lot that match, the highest `priority` wins, ties go to the lowest `id`. No stacking: stacked multipliers are unexplainable on a receipt and unbounded without a second clamp. Floor and ceiling bound the result relative to the base fare.
4. **Effect = `multiplier_bps` and/or flat `surcharge_amount`.** `priced = round_half_up(base * multiplier_bps / 10000) + surcharge_amount`, clamped to `[round_half_up(base * floor_bps / 10000), round_half_up(base * ceiling_bps / 10000)]`, then rounded half up to `round_to`. Applied AFTER the daily cap (the cap is part of the base fare), so a capped day still scales.
5. **Occupancy is measured, not forecast.** `occupancy_pct = floor(100 * (open sessions of the group + active holds of the group) / group capacity)` at the evaluation instant, group capacity exactly as `capacity_snapshot` derives it (active bays of the group when bays are drawn, else `usable_capacity(settings capacity, out of service)`). When the capacity is unknown (`heavy`, or `0`) the occupancy is null and any rule with an occupancy bound does not match. The session being inserted is NOT counted (the `BEFORE INSERT` trigger runs before the row exists, and `check_in` has already turned the plate's own hold into `used`).
6. **Weekday mask and local time window.** Evaluated in the lot's `business_timezone` (`coalesce(parking_settings.business_timezone, 'America/Bogota')`) on `new.entry_time`. `weekdays` is a bitmask over ISO weekdays (Mon = 1, Tue = 2, Wed = 4, Thu = 8, Fri = 16, Sat = 32, Sun = 64; null = every day). A window with `from_time > to_time` crosses midnight; the weekday bit refers to the day on which the window STARTS (the after-midnight part uses the previous day's bit).
7. **Offline-replayed check-ins can never be surcharged.** A queued check-in is replayed with `p_client_entry_time`; the operator could not be shown a price. When `new.entry_time < now() - interval '5 minutes'` the trigger only keeps a lock whose effect on the category's hourly tariff is `<=` the tariff (a discount); a dearer result produces no lock. Windows are still evaluated at `entry_time`; occupancy is the one at replay time (the best the server knows).
8. **A public-page hold locks the price it promised.** `category_reservations.pricing_lock` is written by a `BEFORE INSERT` trigger when `source = 'public'` (and by a `BEFORE UPDATE OF source` trigger when a waitlist offer becomes `public`). When the session trigger finds the plate's consumed hold (status `used`, window containing `entry_time` plus the grace) with a lock, the session takes the cheaper of the hold lock and the lock computed now, comparing both applied to the category's hourly tariff; a tie keeps the hold lock. Operator holds (`source = 'app'`) are not priced (nobody was shown a price).
9. **Public price keys are additive.** `public_availability` keeps `hourly_amount` (the base tariff) and gains per category `current_hourly_amount`, `price_rule`, `price_multiplier_bps`, `price_tier` and a top-level `pricing` object. The page shows the current price and, when it differs, the usual price.
10. **Simulation recomputes history with the same rule function.** `pricing_simulate` evaluates `pricing_rule_matches` (the same predicate the trigger uses) for the closed sessions of the last N days, optionally against a candidate rule set that is not saved yet.
11. **Rules and settings are not in the versioned set.** `pricing_rules` is a new table written only through RPCs (online, never queued in the outbox, so no `version` column and no `row_version_guard`). The four `pricing_*` settings columns live in `parking_settings`, which is already versioned: an RPC write bumps `parking_settings.version` automatically; the Flutter `ParkingSettings` entity is NOT extended, so a queued offline settings diff never carries these columns and cannot overwrite them.
12. **Inert by default.** `parking_settings.pricing_enabled` defaults to false: the triggers return at once with no lock and every consumer behaves as before this change.

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

Two migrations (names fixed, numbers = "next free at implementation time", in this order): `<NEXT>_dynamic_pricing.sql` (settings, table, columns, pure functions, triggers, the hook) and `<NEXT+1>_dynamic_pricing_rpcs.sql` (admin RPCs, quote, session/reservation lock reads, simulation, report, availability decoration).

```sql
alter table public.parking_settings
    add column if not exists pricing_enabled boolean not null default false,
    add column if not exists pricing_floor_bps integer not null default 10000,
    add column if not exists pricing_ceiling_bps integer not null default 15000,
    add column if not exists pricing_round_to integer not null default 1;
alter table public.parking_settings drop constraint if exists parking_settings_pricing_check;
alter table public.parking_settings add constraint parking_settings_pricing_check check (
    pricing_floor_bps between 1000 and 10000
    and pricing_ceiling_bps between 10000 and 50000
    and pricing_round_to between 1 and 1000);

create table if not exists public.pricing_rules (
    id                 serial      primary key,
    lot_id             integer     not null references public.parking_lots(id),
    name               varchar(80) not null,
    active             boolean     not null default true,
    priority           integer     not null default 100 check (priority between 0 and 1000),
    group_name         text        check (group_name in ('car', 'moto', 'heavy')),
    min_occupancy_pct  integer     check (min_occupancy_pct between 0 and 100),
    max_occupancy_pct  integer     check (max_occupancy_pct between 0 and 100),
    weekdays           integer     check (weekdays between 1 and 127),
    from_time          time,
    to_time            time,
    multiplier_bps     integer     not null default 10000 check (multiplier_bps between 1000 and 50000),
    surcharge_amount   integer     not null default 0 check (surcharge_amount between 0 and 100000000),
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now(),
    constraint pricing_rules_name_check check (length(btrim(name)) between 1 and 80),
    constraint pricing_rules_band_check check (
        min_occupancy_pct is null or max_occupancy_pct is null
        or min_occupancy_pct <= max_occupancy_pct),
    constraint pricing_rules_window_check check (
        (from_time is null) = (to_time is null)
        and (from_time is null or from_time <> to_time)),
    constraint pricing_rules_effect_check check (
        multiplier_bps <> 10000 or surcharge_amount > 0),
    constraint pricing_rules_name_key unique (lot_id, name)
);
create index if not exists ix_pricing_rules_lot_active
    on public.pricing_rules (lot_id, priority desc, id) where active;

alter table public.parking_sessions
    add column if not exists pricing_lock jsonb;
alter table public.category_reservations
    add column if not exists pricing_lock jsonb;

alter table public.pricing_rules enable row level security;
revoke all on public.pricing_rules from anon, authenticated;
grant select on public.pricing_rules to authenticated;
drop policy if exists pricing_rules_read on public.pricing_rules;
create policy pricing_rules_read on public.pricing_rules
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

drop trigger if exists trg_audit_row on public.pricing_rules;
create trigger trg_audit_row after insert or update or delete on public.pricing_rules
    for each row execute function public.record_audit();
```

Notes:

- `supabase/tests/rpc_test.sql` already asserts that every public table has RLS enabled; `pricing_rules` complies. Anon has no grant (a test asserts `insufficient_privilege`). Writes happen only inside the `security definer` RPCs below. `pricing_rules` is NOT versioned (no `version` column, no `row_version_guard` trigger) and has no outbox mutation (Decision 11).
- `record_audit()` strips only a column named `pin_hash`; `pricing_rules` has no secret. `parking_settings` is already audited, so changes to the four settings columns appear in `audit_log` with no extra code.
- `parking_sessions.pricing_lock` and `category_reservations.pricing_lock` are written only by the triggers below. Existing rows keep `null` (identity): old sessions are never repriced.
- `pricing_lock` version 1 shape (the contract of the column; every function that builds it MUST emit exactly these keys):

```json
{"v": 1, "rule_id": 7, "rule_name": "Alta ocupacion", "kind": "multiplier",
 "multiplier_bps": 12000, "surcharge_amount": 0,
 "floor_bps": 8000, "ceiling_bps": 15000, "round_to": 1,
 "occupancy_pct": 85, "locked_at": "2026-11-12T15:04:05Z", "source": "checkin"}
```

`kind` is `multiplier` (surcharge 0), `surcharge` (multiplier 10000) or `both`. `source` is `checkin` (computed online), `offline` (computed at a replay and discount-only), or `reservation` (copied from the consumed hold). `rule_id` may be null if the rule is later deleted (the snapshot keeps the name).

### Pure functions (internal)

All created in the first migration. `revoke all on function ... from public, anon, authenticated;` on every one of them (internal; called only by definer code and the triggers). `language sql` or `plpgsql`, `set search_path = public`.

| Function | Notes |
|---|---|
| `pricing_apply_detail(p_lock jsonb, p_base integer) returns jsonb` (immutable) | `{ "amount": int, "clamped": "floor"\|"ceiling"\|null }`. Algorithm below. |
| `pricing_apply(p_lock jsonb, p_base integer) returns integer` (immutable) | `(pricing_apply_detail(p_lock, p_base) ->> 'amount')::integer` |
| `pricing_group_capacity(p_lot integer, p_group text) returns integer` (stable) | active `parking_spots` of the group when any spot of the group exists, else `usable_capacity(car_capacity or moto_capacity, car_out_of_service or moto_out_of_service)`; `0` for `heavy` or unconfigured |
| `pricing_group_occupancy(p_lot integer, p_group text) returns integer` (stable) | `null` when capacity is `0`; else `floor(100 * (open + holds) / capacity)`, where `open` = open `parking_sessions` of the lot whose vehicle category has `category_group(c.name) = p_group`, `holds` = `category_reservations` with `status = 'active' and reserved_until > now()` of the same group. May exceed 100 (clamp with `least(..., 999)`). |
| `pricing_rule_matches(p_rule public.pricing_rules, p_group text, p_local timestamp, p_occupancy integer) returns boolean` (immutable) | The ONE predicate for triggers, quote and simulation. Below. |
| `pricing_identity_lock(p_lot integer) returns jsonb` (stable) | version 1 lock with `rule_id null`, `rule_name ''`, `kind 'multiplier'`, `multiplier_bps 10000`, `surcharge_amount 0` and the lot's current floor/ceiling/round, `source 'checkin'`; applies as the identity |
| `pricing_lock_for(p_lot integer, p_category_id integer, p_at timestamptz, p_allow_surcharge boolean default true) returns jsonb` (stable, `security definer`) | The lock the rules give at `p_at`, or `null`. Below. |

`pricing_apply_detail` (normative; integers only; `/` is integer division on non-negative operands):

1. `p_lock is null or p_base <= 0` returns `{amount: p_base, clamped: null}` (an old session, a pass holder base of 0).
2. `raw := (p_base * multiplier_bps + 5000) / 10000 + surcharge_amount`.
3. `lo := (p_base * floor_bps + 5000) / 10000`, `hi := (p_base * ceiling_bps + 5000) / 10000`; `clamped := 'floor'` when `raw < lo`, `'ceiling'` when `raw > hi`, else null; `value := least(greatest(raw, lo), hi)`.
4. `step := round_to`; `amount := ((value + step / 2) / step) * step` (half up). Rounding is last and may move the result by less than `step / 2` outside `[lo, hi]`.
5. The function is monotonic non-decreasing in `p_base` (all operations are), which `fare_quote`'s `free_minutes` rule relies on.

`pricing_rule_matches` (normative): `p_rule.active` AND (`group_name is null or group_name = p_group`) AND occupancy: when both `min_occupancy_pct` and `max_occupancy_pct` are null the rule matches any occupancy; otherwise `p_occupancy is not null and p_occupancy >= coalesce(min, 0) and p_occupancy <= coalesce(max, 100)` AND time:

```
case
  when from_time is null then weekday_ok(today)
  when from_time < to_time then p_local::time >= from_time and p_local::time < to_time and weekday_ok(today)
  else (p_local::time >= from_time and weekday_ok(today))
    or (p_local::time <  to_time   and weekday_ok(yesterday))
end
weekday_ok(d) = weekdays is null or (weekdays & (1 << (extract(isodow from d)::integer - 1))) <> 0
today = p_local, yesterday = p_local - interval '1 day'
```

`pricing_lock_for(p_lot, p_category_id, p_at, p_allow_surcharge)`:

1. Load `parking_settings` of `p_lot`; `pricing_enabled` false or no row returns null.
2. The category must belong to `p_lot` (`categories.id = p_category_id and lot_id = p_lot`), else null. `g := category_group(c.name)`.
3. `tz := coalesce(business_timezone, 'America/Bogota')`; `local := p_at at time zone tz`; `occ := pricing_group_occupancy(p_lot, g)`.
4. Pick the rule: `select r.* from pricing_rules r where r.lot_id = p_lot and pricing_rule_matches(r, g, local, occ) order by r.priority desc, r.id asc limit 1`. None returns null.
5. Build the version 1 lock (`source = 'checkin'`, `locked_at = now()`, floor/ceiling/round from settings, `occupancy_pct = occ`).
6. `p_allow_surcharge = false`: `ref := hourly tariff of the category in the lot (active, order by id, limit 1)`; when `pricing_apply(lock, coalesce(ref, 0)) > coalesce(ref, 0)` return null (a dearer lock is dropped, a cheaper one is kept).
7. Return the lock.

### Triggers (all `security definer`, `set search_path = public`, `for each row`)

| Trigger | Table / event | Action |
|---|---|---|
| `trg_parking_sessions_pricing_lock` | `parking_sessions` BEFORE INSERT | `lock_session_price()`, steps below |
| `trg_parking_sessions_pricing_lock_guard` | `parking_sessions` BEFORE UPDATE OF `pricing_lock` | `raise exception 'PricingLockImmutableError'` when `new.pricing_lock is distinct from old.pricing_lock` |
| `trg_category_reservations_pricing_lock` | `category_reservations` BEFORE INSERT | when `new.source = 'public'`, `new.pricing_lock is null` and the lot has `pricing_enabled`: `new.pricing_lock := coalesce(pricing_lock_for(new.lot_id, new.category_id, now(), true), pricing_identity_lock(new.lot_id))` (an identity lock is stored when no rule matches, so the promise "usual price" is recorded too) |
| `trg_category_reservations_pricing_lock_claim` | `category_reservations` BEFORE UPDATE OF `source` | same body when `old.source <> 'public' and new.source = 'public' and new.pricing_lock is null` (a claimed waitlist offer; a no-op while the waitlist change is not merged) |

`lock_session_price()` (BEFORE INSERT on `parking_sessions`), normative:

1. `new.pricing_lock is not null` (imports, tests) returns `new` unchanged.
2. `lot := new.lot_id`; `settings.pricing_enabled` false returns `new` (no lock). Resolve `category_id` from `vehicles` (`new.vehicle_id`); none returns `new`.
3. `offline := new.entry_time < now() - interval '5 minutes'`.
4. `current := pricing_lock_for(lot, category_id, new.entry_time, not offline)`; when `offline` set `current.source := 'offline'`.
5. `held`: the newest consumed hold of the plate: `select r.pricing_lock from category_reservations r join vehicles v on v.plate = r.plate where v.id = new.vehicle_id and r.lot_id = lot and r.status = 'used' and r.pricing_lock is not null and r.reserved_from <= new.entry_time and r.reserved_until + public.reservation_grace(lot) > new.entry_time order by r.id desc limit 1`; `held.source := 'reservation'`.
6. `ref := hourly tariff` (as in `pricing_lock_for` step 6, `coalesce(..., 0)`); `held_price := pricing_apply(held, ref)`, `current_price := pricing_apply(current, ref)` (a null lock applies as identity: price = `ref`).
7. Winner: no `held` means `current`; no `current` and `held_price <= ref` means `held`; otherwise the lower price wins, a tie keeps `held`. A winner whose effect is identity (`current` null and `held_price > ref`, or both null) leaves `new.pricing_lock` null.
8. `new.pricing_lock := winner`. The trigger never raises (wrap steps 2-8 in `begin ... exception when others then return new; end`): a pricing failure must not stop a vehicle from entering; the session then simply has no lock (identity), which is the customer-safe outcome.

### The hook (`fare_pricing_step`)

Replaces the no-op owned by `add-merchant-validations` (`create or replace function public.fare_pricing_step(p_session_id integer, p_base integer) returns jsonb`, same language/volatility/security attributes and the same revokes as that change declared; do not add a parameter):

```sql
-- body (normative)
-- lock := (select s.pricing_lock from parking_sessions s where s.id = p_session_id)
-- if lock is null or p_base <= 0 then return {"amount": p_base, "pricing": null}
-- d := pricing_apply_detail(lock, p_base)
-- return {"amount": d.amount,
--         "pricing": {"rule_id": lock.rule_id, "rule_name": lock.rule_name, "kind": lock.kind,
--                     "multiplier_bps": lock.multiplier_bps, "surcharge_amount": lock.surcharge_amount,
--                     "delta": d.amount - p_base, "clamped": d.clamped,
--                     "locked_at": lock.locked_at, "source": lock.source}}
```

It is deterministic given the stored lock, so previews, the public page, the check-out and a reprint of a closed session all produce the same line.

## RPC signatures

All new names (no overload traps; no parameter is added to an existing function). All `language plpgsql`, `set search_path = public`. Typed errors are `raise exception '<Name>Error'` (PostgREST message = name, mapped by `mapSupabaseError`).

| Function | Grants | Auth | Notes |
|---|---|---|---|
| `get_pricing_settings() returns jsonb` (stable, definer) | authenticated | `require_lot_admin()` | `{"enabled": bool, "floor_bps": int, "ceiling_bps": int, "round_to": int}` |
| `set_pricing_settings(p_enabled boolean default null, p_floor_bps integer default null, p_ceiling_bps integer default null, p_round_to integer default null) returns jsonb` | authenticated | `require_lot_admin()` | `null` keeps the value; out of range raises `InvalidPricingSettingsError`; same shape as `get` |
| `list_pricing_rules() returns jsonb` (stable, definer) | authenticated | `require_lot_admin()` | array ordered `priority desc, id`: `{"id", "name", "active", "priority", "group", "min_occupancy_pct", "max_occupancy_pct", "weekdays", "from_time", "to_time", "multiplier_bps", "surcharge_amount", "updated_at"}`; `group` is `null\|car\|moto\|heavy`; times are `"HH24:MI"` strings or null |
| `save_pricing_rule(p_name text, p_priority integer, p_group text, p_min_occupancy integer, p_max_occupancy integer, p_weekdays integer, p_from_time time, p_to_time time, p_multiplier_bps integer, p_surcharge_amount integer, p_active boolean default true, p_id integer default null) returns jsonb` | authenticated | `require_lot_admin()` | insert when `p_id` is null, else update a rule of the active lot; returns one rule object (list shape) |
| `delete_pricing_rule(p_id integer) returns jsonb` | authenticated | `require_lot_admin()` | `{"id": int, "deleted": true}`; open sessions keep their snapshot |
| `pricing_quote(p_category_id integer) returns jsonb` (stable, definer) | authenticated | `require_app_user()`; category must belong to `current_lot_id()` else `CategoryNotFoundError` | what an entry would be priced at now (online semantics, no offline restriction) |
| `pricing_session_lock(p_session_id integer) returns jsonb` (stable, definer) | authenticated | `require_app_user()`; session lot must equal `current_lot_id()` else `SessionNotFoundError` | the stored lock of a session (open or closed) with display numbers, or `null` |
| `public_reservation_pricing(p_lot_id integer, p_reservation_id bigint, p_customer_phone text) returns jsonb` (stable, definer) | anon, authenticated (`revoke all ... from public` first) | id + lot + phone match, `source = 'public'`, `status = 'active'`, `reserved_until > now()` (same bar as `public_reservation_lookup`, phone normalised the same way) | the hold's lock summary, or `null` |
| `pricing_simulate(p_days integer default 30, p_rules jsonb default null) returns jsonb` (stable, definer) | authenticated | `require_lot_admin()` | read-only preview |
| `report_pricing_impact(p_start_date date, p_end_date date) returns jsonb` (stable, definer) | authenticated | `require_admin()` (like `report_hourly_traffic`) | real impact of locks |
| `pricing_decorate_availability(p_lot_id integer, p_payload jsonb) returns jsonb` (stable, definer) | none (internal, revoke from public, anon, authenticated) | n/a | adds the price keys to the public payload |

Security-definer functions stamp/filter `lot_id` explicitly (definer functions bypass RLS); `current_lot_id()` comes from the `x-lot-id` header (`0032`).

### Return shapes

`pricing_quote`:

```json
{"enabled": true, "category_id": 3, "group": "car", "at": "2026-11-12T15:04:05Z",
 "occupancy_pct": 85, "rule": {"id": 7, "name": "Alta ocupacion"},
 "multiplier_bps": 12000, "surcharge_amount": 0,
 "hourly_base": 3000, "hourly_current": 3600, "tier": "higher"}
```

`tier` is `base` (no rule or equal), `higher` or `lower` (`hourly_current` compared with `hourly_base`). Disabled lot or no matching rule: `rule: null`, `multiplier_bps: 10000`, `surcharge_amount: 0`, `hourly_current = hourly_base`, `tier: "base"`; `enabled` is the lot switch. `hourly_base` is `0` when the category has no hourly tariff.

`pricing_session_lock` and `public_reservation_pricing` (the latter omits `session_id`; unknown or unlocked returns `null`):

```json
{"session_id": 120, "rule_id": 7, "rule_name": "Alta ocupacion", "kind": "multiplier",
 "multiplier_bps": 12000, "surcharge_amount": 0, "hourly_base": 3000, "hourly_locked": 3600,
 "occupancy_pct": 85, "locked_at": "...", "source": "checkin"}
```

`hourly_locked = pricing_apply(lock, hourly_base)` using the lock's own floor/ceiling/round snapshot.

`pricing_simulate`:

```json
{"days": 30, "from": "2026-10-13T05:00:00Z", "to": "2026-11-12T15:04:05Z",
 "sessions_considered": 412, "sessions_affected": 97,
 "base_total": 3120000, "simulated_total": 3275400, "delta": 155400, "delta_pct_bps": 498,
 "at_floor": 3, "at_ceiling": 5,
 "by_rule": [{"rule_id": 7, "name": "Alta ocupacion", "sessions": 80, "delta": 148200}],
 "by_hour": [{"hour": 17, "sessions": 22, "delta": 61000}],
 "assumptions": {"holds_excluded": true, "tariffs": "current", "capacity": "current"}}
```

`delta_pct_bps` is `round(delta * 10000 / base_total)` or `null` when `base_total = 0`. `by_hour` lists only hours with sessions, the local hour of `entry_time`. Candidate rules passed in `p_rules` are validated like `save_pricing_rule`; they get negative ids `-1, -2, ...` in array order in `by_rule`.

`report_pricing_impact`:

```json
{"from": "2026-11-01", "to": "2026-11-30", "locked_sessions": 190, "surcharged_sessions": 120,
 "discounted_sessions": 70, "extra_revenue": 410000, "discount_given": 90000, "net_delta": 320000,
 "by_rule": [{"rule_id": 7, "name": "Alta ocupacion", "sessions": 120, "delta": 410000}]}
```

### Typed errors

New: `InvalidPricingRuleError` (any field of a rule out of range, bad window, inverted band, no effect, bad group, empty or too long name, invalid candidate rule in a simulation), `DuplicatePricingRuleError` (unique `(lot_id, name)`), `PricingRuleNotFoundError` (id missing or of another lot), `InvalidPricingSettingsError`, `PricingSimulationTooLargeError` (more than 20000 sessions in the window), `PricingLockImmutableError`. Existing and reused: `AdminRequiredError`, `LotRequiredError`, `CategoryNotFoundError`, `SessionNotFoundError`, `InvalidReportRangeError` (`pricing_simulate` with `p_days` outside 1..90, bad report range), `InvalidTokenError`.

### Function algorithms (normative steps)

**`save_pricing_rule`**: (1) `lot := require_lot_admin()`; (2) validate: name trimmed 1..80, priority 0..1000, group null or in (`car`,`moto`,`heavy`), occupancy bounds 0..100 and `min <= max` when both present, weekdays null or 1..127, `p_from_time` and `p_to_time` both null or both present and different, multiplier 1000..50000, surcharge 0..100000000, effect present (`multiplier <> 10000 or surcharge > 0`), all else `InvalidPricingRuleError`; (3) insert or update (`updated_at = now()`), unique violation on `(lot_id, name)` raises `DuplicatePricingRuleError`; update with unknown id or another lot raises `PricingRuleNotFoundError`; (4) return the rule object. The audit trigger records the actor.

**`pricing_quote`**: (1) `require_app_user()`; (2) category of `current_lot_id()` else `CategoryNotFoundError`; (3) `lock := pricing_lock_for(lot, category, now(), true)`; (4) `hourly_base` from the tariff; `hourly_current := pricing_apply(lock, hourly_base)`; (5) shape above.

**`pricing_simulate`**: (1) `require_lot_admin()`; (2) `p_days` outside 1..90 raises `InvalidReportRangeError`; (3) rule set = `p_rules` (validated) else the lot's `active` stored rules; empty set returns zeros; (4) sessions = `parking_sessions` of the lot with `status = 'closed'`, `lost_ticket = false`, `payment_method is distinct from 'monthly_pass'`, `entry_time >= now() - make_interval(days => p_days)`, count above 20000 raises `PricingSimulationTooLargeError`; (5) per session: `base := fare_breakdown(category, entry, exit, false) ->> 'amount'` (a `MissingHourlyTariffError` skips the session), `group`, `local := entry_time at time zone tz`, `occupancy := floor(100 * count(other sessions of the lot and group with entry_time <= s.entry_time and (exit_time is null or exit_time > s.entry_time), excluding s) / pricing_group_capacity)` (null when capacity 0), first matching rule by `priority desc, id`, lock built exactly like `pricing_lock_for` steps 5 with the current settings, `simulated := pricing_apply(lock, base)`; (6) aggregate. Write nothing.

**`report_pricing_impact`**: (1) `require_admin()` and `current_lot_id()`; (2) `p_start_date <= p_end_date` else `InvalidReportRangeError`; window in the lot timezone like `report_hourly_traffic`; (3) sessions with `status = 'closed'`, `pricing_lock is not null`, `lost_ticket = false`, `payment_method is distinct from 'monthly_pass'`, `gross_amount is not null`, `exit_time` in the window; `delta := gross_amount - (fare_breakdown(...) ->> 'amount')::integer`; (4) aggregate (`extra_revenue` = sum of positive deltas, `discount_given` = sum of absolute negative deltas, `net_delta` = difference).

**`pricing_decorate_availability(p_lot_id, p_payload)`**: if `pricing_enabled` is false returns `p_payload || {"pricing": {"enabled": false}}`; else for each element of `p_payload -> 'categories'` adds `current_hourly_amount` (`pricing_apply(pricing_lock_for(p_lot_id, id, now(), true), hourly_amount)`, `hourly_amount` when no lock), `price_rule` (name or null), `price_multiplier_bps` (10000 when none), `price_tier` (`base|higher|lower`) and returns the payload with `"pricing": {"enabled": true}`. Existing keys (`hourly_amount`, `available`, ...) are never removed or renamed.

### Adding the keys to `public_availability` without breaking the `0101` body

Do NOT copy the `0101` body again. The only edit is a one-line call:

- Case A: `grep -l public_availability_base supabase/migrations/*.sql` finds a file (the forecast change landed). `public_availability` is then a small wrapper. Read its latest body and `create or replace` it with the same text plus `base := public.pricing_decorate_availability(p_lot_id, base);` right after `if base is null then return null; end if;` and before the `||`. Keep the grant to `anon, authenticated`.
- Case B: no `public_availability_base` exists. In `<NEXT+1>_dynamic_pricing_rpcs.sql` do exactly the forecast change's mechanism: `alter function public.public_availability(integer) rename to public_availability_base; revoke all on function public.public_availability_base(integer) from public, anon, authenticated;` and create the wrapper `public_availability(p_lot_id integer) returns jsonb` (stable, definer, `set search_path = public`) whose body is `declare base jsonb := public.public_availability_base(p_lot_id); begin if base is null then return null; end if; return public.pricing_decorate_availability(p_lot_id, base); end`, then `grant execute on function public.public_availability(integer) to anon, authenticated;`. Record in `docs/agent-memory.md` that the forecast change, when it lands, must `create or replace` the wrapper (its design assumes it performs the rename; read `openspec/changes/add-occupancy-forecast/design.md` line ~333 and adapt: the rename must be skipped because `public_availability_base` exists).

## State machines

Rule: `active` <-> `inactive` (`save_pricing_rule` with `p_active`), terminal `deleted` (`delete_pricing_rule`). Only `active` rules of a lot with `pricing_enabled = true` are evaluated. Disabling the lot or deleting a rule never touches existing locks.

Lock lifecycle (one per session):

```
(no lock: lot disabled, no rule matched, identity winner, pre-change session)
        ^
        | trigger at insert
 session insert --+--> locked[checkin]       online entry, rule matched
                  +--> locked[offline]       replay older than 5 min, discount-only rule
                  +--> locked[reservation]   consumed public hold promised a cheaper-or-equal price
 locked[*] --check_out--> consumed (immutable, read by fare_pricing_step forever)
 any state --UPDATE pricing_lock--> PricingLockImmutableError
```

Hold lock: `public` hold insert -> `locked` -> consumed into the session lock, or the hold expires/cancels and the lock dies with the row.

Lock choice at session insert (Decision 8 and 7):

| `held` (hold lock) | `current` (rule now) | offline | Result |
|---|---|---|---|
| none | none | any | no lock |
| none | rule, dearer than base | no | `current` (`checkin`) |
| none | rule, dearer than base | yes | no lock (surcharge dropped) |
| none | rule, cheaper than base | yes | `current` with `source = 'offline'` |
| lock | none | any | `held` if `held` price <= base, else no lock |
| lock | rule | no | the cheaper at the hourly reference, tie keeps `held` |

## Where pricing sits in the interaction

The normative block above is the only statement of ordering. In this change: pricing sits at step 3 and produces `pricing`, never an adjustment line; the lock is read from the session; monthly-pass sales never call `fare_pricing_step`.


## Flutter

New feature `lib/features/pricing/` (admin screen, check-in price chip) plus additive edits in `public_booking`, `check_in`, `check_out`, `core/receipt`, `receipt_printing`, `reports`, `app/router`, `app/di`, `app/shell`.

```text
lib/features/pricing/
  domain/entities/pricing_rule.dart            # PricingRule, PricingRuleDraft
  domain/entities/pricing_settings.dart
  domain/entities/price_quote.dart             # PriceQuote, PriceTier
  domain/entities/session_price_lock.dart      # SessionPriceLock (also used for public holds)
  domain/entities/fare_pricing.dart            # FarePricing (typed view of fare_quote.pricing)
  domain/entities/pricing_simulation.dart      # PricingSimulation, RuleImpact, HourImpact
  domain/entities/pricing_impact_report.dart
  domain/repositories/pricing_repository.dart          # admin port
  domain/repositories/price_quote_repository.dart      # operator + public read port
  application/pricing_cubit.dart               # rules + settings screen
  application/pricing_simulation_cubit.dart
  application/price_quote_cubit.dart           # check-in chip
  infrastructure/pricing_remote_data_source.dart
  infrastructure/pricing_repository_impl.dart
  infrastructure/price_quote_repository_impl.dart
  presentation/pricing_page.dart               # route /pricing (admin)
  presentation/pricing_rule_dialog.dart
  presentation/pricing_settings_card.dart
  presentation/pricing_simulation_sheet.dart
  presentation/price_quote_chip.dart           # check-in
  presentation/applied_rule_tile.dart          # breakdown row
lib/app/router/deferred/pricing_entry.dart     # NEW
lib/app/di/modules/pricing_module.dart         # NEW
```

Entities (Equatable, pure Dart; `fromJson(Map<String, dynamic>)` on the entity like `PublicCategoryAvailability.fromJson`; every integer parsed with `(raw as num?)?.toInt()`):

- `PricingRule {int id, String name, bool active, int priority, String? group, int? minOccupancyPct, int? maxOccupancyPct, int? weekdays, int? fromMinute, int? toMinute, int multiplierBps, int surchargeAmount}` (`fromMinute/toMinute` = minutes since midnight parsed from `"HH:MM"`), getters `Set<int> weekdaySet` (ISO 1..7 from the bitmask), `bool crossesMidnight`, `bool hasSurcharge`, `bool hasMultiplier => multiplierBps != 10000`. `PricingRuleDraft` = the same fields without `id`, plus `int? id` for edits, with `toParams()` producing the `p_*` map for `save_pricing_rule`.
- `PricingSettings {bool enabled, int floorBps, int ceilingBps, int roundTo}`.
- `PriceTier { base, higher, lower }` with `static PriceTier parse(String)` (unknown falls back to `base`). `PriceQuote {bool enabled, int categoryId, int? occupancyPct, int? ruleId, String? ruleName, int multiplierBps, int surchargeAmount, int hourlyBase, int hourlyCurrent, PriceTier tier}` with `bool get isSurge => tier == PriceTier.higher`.
- `SessionPriceLock {int? sessionId, int? ruleId, String ruleName, String kind, int multiplierBps, int surchargeAmount, int hourlyBase, int hourlyLocked, int? occupancyPct, DateTime lockedAt, String source}`.
- `FarePricing {int? ruleId, String ruleName, String kind, int multiplierBps, int surchargeAmount, int delta, String? clamped, DateTime lockedAt, String source}` with `static FarePricing? fromMap(Map<String, Object?>? raw)` (null in, null out). `FareQuote.pricing` (owned by `add-merchant-validations`, `lib/core/fare/fare_quote.dart`) stays a raw `Map<String, Object?>?`; this class is the typed view and `FareQuote`'s constructor is not changed.
- `PricingSimulation {int days, int sessionsConsidered, int sessionsAffected, int baseTotal, int simulatedTotal, int delta, int? deltaPctBps, int atFloor, int atCeiling, List<RuleImpact> byRule, List<HourImpact> byHour}`; `RuleImpact {int ruleId, String name, int sessions, int delta}`; `HourImpact {int hour, int sessions, int delta}`.
- `PricingImpactReport {int lockedSessions, int surchargedSessions, int discountedSessions, int extraRevenue, int discountGiven, int netDelta, List<RuleImpact> byRule}`.

Ports:

```dart
abstract class PricingRepository {                       // admin, online only
  Future<PricingSettings> loadSettings();                // get_pricing_settings
  Future<PricingSettings> saveSettings(PricingSettings s);  // set_pricing_settings
  Future<List<PricingRule>> listRules();                 // list_pricing_rules
  Future<PricingRule> saveRule(PricingRuleDraft draft);  // save_pricing_rule
  Future<void> deleteRule(int id);                       // delete_pricing_rule
  Future<PricingSimulation> simulate({required int days, List<PricingRuleDraft>? candidates});
  Future<PricingImpactReport> impact({required DateTime from, required DateTime to});
}
abstract class PriceQuoteRepository {                    // operator + customer reads
  Future<PriceQuote> quote(int categoryId);              // pricing_quote
  Future<SessionPriceLock?> sessionLock(int sessionId);  // pricing_session_lock
  Future<SessionPriceLock?> reservationLock({required int lotId, required int reservationId, required String phone}); // public_reservation_pricing
}
```

Data sources call the RPCs by name with `p_*` params and wrap every call in `try { ... } catch (error) { throw mapSupabaseError(error); }`. Nothing here uses `SyncOutbox`, `MutationEntity` or Hive (Decision 11); no adapter is added to `hive_adapters.dart`.

Cubits (extend `ResilientCubit`, sealed `Equatable` states, the four UI states, actions reuse `Submission` from `core/state/submission.dart` like `TariffsCubit`):

- `PricingCubit`: `PricingInitial`, `PricingLoading` (skeleton rows), `PricingLoaded({List<PricingRule> rules, PricingSettings settings, Submission submission})` (an empty `rules` list renders the empty state with the "Add rule" action), `PricingFailure(message, {failure})` (retry). Methods: `load()`, `saveRule(PricingRuleDraft)`, `deleteRule(int id)`, `toggleRule(PricingRule rule)`, `saveSettings(PricingSettings)`.
- `PricingSimulationCubit`: `SimulationIdle`, `SimulationRunning` (skeleton), `SimulationDone(PricingSimulation result)` (a result with `sessionsConsidered == 0` renders the empty state "no sessions in that window"), `SimulationFailure(message, {failure})` (retry). Method `run({required int days, List<PricingRuleDraft>? candidates})`.
- `PriceQuoteCubit` (check-in chip): `PriceQuoteLoading`, `PriceQuoteReady(PriceQuote quote)`, `PriceQuoteHidden` (feature disabled, no hourly tariff, or the device is offline: the chip renders nothing or the offline note), `PriceQuoteFailure(message, {failure})` (a small retry text button; check-in itself is never blocked). Method `load(int categoryId)` re-called when the operator changes the category and every 60 s while the screen is open (`Timer`, cancelled in `close()`).

Widgets reused by name: `SectionHeader`, `EmptyState`, `ErrorState`, `StatusChip`, `SkeletonList`, `AppIconButton`, `ConfirmDialog`, `MetricCard`, `MoneyText`, `ListPageScaffold`. No color outside `Theme.of(context)` / `StatusColors` (surge = `warning`, lower price = `success`; never a hex). Every target at least `Layout.minTouch`. Money always through `Money`/`MoneyText`; percentages shown as `multiplierBps / 100` with the `%` sign.

Screens:

- `PricingPage` (`/pricing`, admin-only by default: `route_access.dart` needs NO allowlist entry): `SectionHeader` + `PricingSettingsCard` (switch, floor, ceiling, rounding with inline `errorText` validation: floor 10..100 %, ceiling 100..500 %, round 1..1000), rule list (`ListPageScaffold` + FAB "Add rule", each row: name, active switch, a one-line summary "Carros, ocupacion 80-100 %, lun-vie 17:00-20:00 -> +20 %"), "Simular" button opening `PricingSimulationSheet` (days chips 7/30/90, optional "include unsaved rule" toggle that sends the dialog's draft as a candidate, result as `MetricCard`s and two lists by rule and by hour).
- `PricingRuleDialog`: `AlertDialog(scrollable: true)`, `ChoiceChip` row for group (all, car, moto, heavy: up to five options), two integer fields for the occupancy band, seven `FilterChip`s for weekdays, two time pickers, multiplier and surcharge fields (`Money` formatting for the surcharge), `textInputAction` next/done, inline errors from `InvalidPricingRuleError` mapped to a banner only when no field matches.
- `PriceQuoteChip` (check-in, above the category chips): when `quote.enabled` shows "Tarifa ahora: $3.600/h" with a `StatusChip` ("Mas alta" / "Mas baja") and, when `tier != base`, the usual price in `labelSmall`; semantics label reads the same sentence.
- `AppliedRuleTile`: one row in `FareBreakdownView` (`lib/features/check_out/presentation/widgets/fare_breakdown_view.dart`) "Tarifa dinamica: Alta ocupacion (+20 %)  +$1.800" built from `FarePricing`, shown only when `pricing != null`.
- Reports: a "Impacto de tarifas dinamicas" block in `ReportsPage` (admin) with `MetricCard`s (sessions locked, extra revenue, discounts, net) fed by `report_pricing_impact`; its CSV/PDF reuse `report_csv.dart` / `report_pdf.dart` with three added rows (raw integers in the CSV).

Integration points (verified in the current tree):

- Router: `lib/app/router/app_router.dart` adds `GoRoute(path: 'pricing', ...)` under the shell next to `'tariffs'` (copy the deferred pattern at lines ~292-296: `import 'deferred/pricing_entry.dart' deferred as pricing;`, `pricing.loadLibrary`, `() => pricing.buildPricingEntry()`). `lib/app/router/deferred/pricing_entry.dart` returns a `MultiBlocProvider` of `PricingCubit` and `PricingSimulationCubit` around `PricingPage` (copy `tariffs_entry.dart`). `lib/app/shell/app_destinations.dart`: add `AppDestination('/pricing', _pricing, Icons.trending_up_outlined, Icons.trending_up)` to `managementDestinations` next to `/tariffs` with `String _pricing(AppLocalizations l) => l.navPricing;`.
- DI: `registerPricingModule(GetIt sl)` in `lib/app/di/modules/pricing_module.dart` registers `PricingRemoteDataSource` (lazy singleton over `sl<SupabaseClient>()`), `PricingRepository` and `PriceQuoteRepository` (lazy singletons), `PricingCubit`, `PricingSimulationCubit` and `PriceQuoteCubit` (factories); call it in `lib/app/di/injection.dart` beside `registerTariffsModule` (add the import).
- Check-in: `lib/features/check_in/presentation/check_in_page.dart` hosts `PriceQuoteChip` above the category `ChoiceChip` row (around line 1074) and calls `PriceQuoteCubit.load(categoryId)` on category change; the `check_in` route in `app_router.dart` (path `'check-in'`, line ~180) adds `BlocProvider<PriceQuoteCubit>`. After a successful ONLINE check-in the entry receipt dialog asks `PriceQuoteRepository.sessionLock(session.id)` and passes its `ruleName`/`hourlyLocked` into `ReceiptData` (below); an offline (`pendingSync`) receipt prints the pending note instead. `CheckInCubit`, `CreateCheckIn`, the DTO and the outbox payload are NOT changed.
- Check-out: `CheckOutPreview` (`lib/features/check_out/domain/entities/check_out_preview.dart`) gains `final FarePricing? pricing;` parsed from the preview's `quote.pricing` object (the preview embeds the whole `fare_quote` result under `quote`, per `add-merchant-validations`; read its design before wiring and use the key it defines); `FareBreakdownView` renders `AppliedRuleTile` when present. `CheckOutReceipt` + DTO read `pricing` from the check-out response (that change's response carries `pricing` from the quote; null otherwise).
- `ReceiptData` (`lib/core/receipt/receipt_data.dart`) gains two optional fields, `final String? pricingLabel;` (already formatted, e.g. "Alta ocupacion x1,20") and `final int pricingDelta;` (default 0), plus `ReceiptLabels.pricingRule` (`lib/core/receipt/receipt_labels.dart`). `lib/core/widgets/receipt_card.dart`, `esc_pos_generator.dart` (after the amount block, before the discount lines) and `system_dialog_receipt_printer.dart` print `pricingLabel` and, on check-out receipts, the delta when non-zero. A receipt with `pricingLabel == null` renders exactly as today. Core never imports `features/pricing`: the call site builds the strings.
- History reprint (`lib/features/vehicle_history`): the reprint action calls `PriceQuoteRepository.sessionLock(id)` (online only; offline the line is omitted) and fills the same two fields.
- Public booking: `PublicCategoryAvailability` (`lib/features/public_booking/domain/entities/public_booking.dart`) gains `currentHourlyAmount` (defaults to `hourlyAmount` when the key is absent, so an older database still parses), `priceRule` (`String?`), `priceTier` (`PriceTier`, default base). `public_booking_page.dart` shows "Ahora $3.600/h" with a "Precio normal $3.000/h" caption when `priceTier != base`. After a booking is created or looked up, `PublicBookingCubit` calls `PriceQuoteRepository.reservationLock(...)` (anonymous RPC `public_reservation_pricing`) and the confirmation card shows "Tarifa fijada: $3.600/h hasta tu llegada" (`lockedRate`). The public QR page (`lib/features/evidence`) shows the rule line when the summary's `quote.pricing` is present.
- Failure texts: add the new typed names to `lib/core/l10n/failure_messages.dart` `_byCode`.

## l10n

Add to `lib/l10n/app_es.arb` (template) and `lib/l10n/app_en.arb`, then `flutter gen-l10n`. Placeholders use ICU like the existing keys.

| Key | ES | EN |
|---|---|---|
| `navPricing` | Tarifas dinamicas | Dynamic pricing |
| `pricingTitle` | Tarifas dinamicas | Dynamic pricing |
| `pricingEnabled` | Activar tarifas dinamicas | Enable dynamic pricing |
| `pricingEnabledHint` | Con la opcion apagada se cobra siempre la tarifa normal. | While off, the normal tariff is always charged. |
| `pricingFloor` | Minimo (% de la tarifa) | Floor (% of the tariff) |
| `pricingCeiling` | Maximo (% de la tarifa) | Ceiling (% of the tariff) |
| `pricingRoundTo` | Redondear a | Round to |
| `pricingSettingsSaved` | Ajustes guardados | Settings saved |
| `pricingRulesTitle` | Reglas | Rules |
| `pricingNoRules` | Aun no hay reglas | No rules yet |
| `pricingNoRulesHint` | Crea una regla para subir o bajar la tarifa segun ocupacion u horario. | Create a rule to raise or lower the tariff by occupancy or schedule. |
| `pricingAddRule` | Agregar regla | Add rule |
| `pricingEditRule` | Editar regla | Edit rule |
| `pricingRuleName` | Nombre | Name |
| `pricingRulePriority` | Prioridad (mayor gana) | Priority (higher wins) |
| `pricingRuleGroup` | Tipo de vehiculo | Vehicle type |
| `pricingRuleGroupAll` | Todos | All |
| `pricingRuleOccupancyFrom` | Ocupacion desde (%) | Occupancy from (%) |
| `pricingRuleOccupancyTo` | Ocupacion hasta (%) | Occupancy to (%) |
| `pricingRuleWeekdays` | Dias | Days |
| `pricingRuleFromTime` | Desde | From |
| `pricingRuleToTime` | Hasta | To |
| `pricingRuleMultiplier` | Multiplicador (%) | Multiplier (%) |
| `pricingRuleSurcharge` | Recargo fijo | Flat surcharge |
| `pricingRuleActive` | Activa | Active |
| `pricingRuleSummary` | `{group}, {when}: {effect}` | `{group}, {when}: {effect}` |
| `pricingRuleSaved` | Regla guardada | Rule saved |
| `pricingRuleDeleted` | Regla eliminada | Rule deleted |
| `pricingRuleDeleteConfirm` | Las entradas ya registradas conservan su tarifa. Eliminar esta regla? | Vehicles already inside keep their rate. Delete this rule? |
| `pricingSimulate` | Simular | Simulate |
| `pricingSimulateDays` | Ultimos `{days}` dias | Last `{days}` days |
| `pricingSimIncludeDraft` | Incluir la regla sin guardar | Include the unsaved rule |
| `pricingSimBase` | Cobro con tarifa normal | Charged at the normal tariff |
| `pricingSimTotal` | Cobro simulado | Simulated total |
| `pricingSimDelta` | Diferencia | Difference |
| `pricingSimAffected` | `{count}` entradas afectadas | `{count}` sessions affected |
| `pricingSimAtLimits` | `{floor}` en el minimo, `{ceiling}` en el maximo | `{floor}` at the floor, `{ceiling}` at the ceiling |
| `pricingSimByRule` | Por regla | By rule |
| `pricingSimByHour` | Por hora de entrada | By entry hour |
| `pricingSimEmpty` | No hay entradas cobradas en ese periodo. | No charged sessions in that period. |
| `pricingSimNote` | Usa tarifas y capacidad actuales y no cuenta reservas. | Uses current tariffs and capacity and ignores holds. |
| `pricingReportTitle` | Impacto de tarifas dinamicas | Dynamic pricing impact |
| `pricingReportLocked` | Entradas con tarifa fijada | Sessions with a locked rate |
| `pricingReportExtra` | Ingreso adicional | Extra revenue |
| `pricingReportDiscount` | Descuentos por tarifa | Rate discounts |
| `pricingReportNet` | Efecto neto | Net effect |
| `priceQuoteNow` | Tarifa ahora: `{amount}`/h | Rate now: `{amount}`/h |
| `priceQuoteUsually` | Normal: `{amount}`/h | Usual: `{amount}`/h |
| `priceQuoteHigher` | Mas alta | Higher |
| `priceQuoteLower` | Mas baja | Lower |
| `priceQuoteOffline` | La tarifa se confirma al sincronizar. | The rate is confirmed when synced. |
| `publicPriceNow` | Ahora `{amount}`/h | Now `{amount}`/h |
| `publicPriceUsually` | Precio normal `{amount}`/h | Usual price `{amount}`/h |
| `publicRateLocked` | Tarifa fijada: `{amount}`/h hasta tu llegada | Locked rate: `{amount}`/h until you arrive |
| `farePricingRule` | Tarifa dinamica: `{name}` (`{percent}`) | Dynamic rate: `{name}` (`{percent}`) |
| `receiptRateLine` | Tarifa: `{name}` | Rate: `{name}` |
| `fareRateLocked` | Tarifa fijada a la entrada | Rate locked at entry |
| `errorInvalidPricingRule` | Revisa la regla: hay valores fuera de rango. | Check the rule: some values are out of range. |
| `errorDuplicatePricingRule` | Ya existe una regla con ese nombre. | A rule with that name already exists. |
| `errorPricingRuleNotFound` | La regla ya no existe. | The rule no longer exists. |
| `errorInvalidPricingSettings` | Minimo, maximo o redondeo fuera de rango. | Floor, ceiling or rounding out of range. |
| `errorPricingSimulationTooLarge` | Demasiadas entradas: elige menos dias. | Too many sessions: pick fewer days. |

Placeholders: `pricingSimulateDays` and `{days}` (int), `pricingSimAffected` `{count}` (int), `pricingSimAtLimits` `{floor}`/`{ceiling}` (int), `priceQuoteNow`/`priceQuoteUsually`/`publicPriceNow`/`publicPriceUsually`/`publicRateLocked` `{amount}` (String, already formatted by `Money`), `farePricingRule` `{name}` and `{percent}` (String), `receiptRateLine` `{name}`, `pricingRuleSummary` three Strings. Add each failure key to `failure_messages.dart`: `InvalidPricingRuleError` -> `errorInvalidPricingRule`, `DuplicatePricingRuleError` -> `errorDuplicatePricingRule`, `PricingRuleNotFoundError` -> `errorPricingRuleNotFound`, `InvalidPricingSettingsError` -> `errorInvalidPricingSettings`, `PricingSimulationTooLargeError` -> `errorPricingSimulationTooLarge`. `PricingLockImmutableError` is never user-facing (falls back to the generic message).

## Offline behaviour

- Admin CRUD, settings, simulation and the report are online only (AGENTS section 5: nothing here is cash or a queued write); a `NetworkFailure` renders the error state with retry; nothing is queued and `MutationEntity`/`PendingMutation` are untouched.
- Check-in screen offline: `PriceQuoteCubit` emits `PriceQuoteHidden` and the page shows `priceQuoteOffline`. The queued check-in payload is unchanged (still carries `client_entry_time`). At replay the trigger evaluates the rules at that `entry_time` (windows) and the replay-time occupancy, and drops any surcharge (Decision 7). The pending-sync entry receipt prints the pending line and no rate.
- Check-out offline: the queued check-out carries `client_exit_time`. When it replays, `check_out` calls `fare_quote(session, exit_at)` with the stored lock: the pricing line depends only on the lock and the base fare for the stay up to `client_exit_time`, never on the current occupancy, rules or the time of the replay. A lot that disabled pricing or deleted the rule in between does not change an existing lock.
- The queued check-out receipt keeps showing no amount until the replay (existing `pendingSync` behaviour).
- Public page and QR page are online only, as today.

## Security analysis

| Actor | Can | Cannot |
|---|---|---|
| anon | `public_availability` (price keys), `public_reservation_pricing` (id + lot + phone), `public_session_summary` (existing, plate is the key) | select `pricing_rules`; execute admin RPCs, `pricing_quote`, `pricing_session_lock`, `pricing_simulate`, internal functions |
| operator | `pricing_quote`, `pricing_session_lock` for the active lot; check-in/check-out (locks are written by triggers) | read `pricing_rules` (RLS needs lot admin), save or delete rules, change settings, simulate, report (`AdminRequiredError`) |
| lot admin | all operator rights + rule CRUD, settings, simulation | other lots (`LotRequiredError`/policy), rewrite a lock (`PricingLockImmutableError`) |
| service role / postgres | migrations, backfills (can disable the guard trigger deliberately) | n/a |

- Lot isolation: every definer function filters by `lot_id`; `pricing_rules` policy uses `current_lot_id()` AND `is_lot_admin`; `pricing_lock_for` verifies the category belongs to the lot; `public_reservation_pricing` requires the lot, id and phone to match.
- Integrity of money: the lock is written only by a trigger from server data (an operator cannot send a multiplier through `check_in`: it has no such parameter), is immutable after insert, and `fare_pricing_step` never reads settings or rules at check-out. The multiplier is bounded by the floor and ceiling snapshot (`10 %..500 %` at the schema level, default `100 %..150 %`).
- Customer protection: surcharges cannot be applied to a session the operator could not show a price for (offline replays) and a public hold can never end up dearer than the price it was booked at.
- Failure containment: `lock_session_price` never raises; a pricing bug degrades to "no lock" (the normal tariff), never to a blocked entry or an overcharge.
- Enumeration: `public_reservation_pricing` has the same bar as `public_reservation_lookup` (hold id plus the phone it was booked with). Prices are public anyway (`/reserve` shows them).
- Abuse of a public hold to lock a cheap rate and arrive at peak: bounded by the hold window (<= 24 h) and the existing booking throttle and captcha (`add-public-booking-captcha`); see open question 3.
- Audit: `pricing_rules` and the four settings columns go to `audit_log` through `record_audit()` with the actor.
- Logs: no function logs plates or phones.

## Worked fare examples

Fixtures (shared by the three money changes): car category, hourly 3000, nightly 2000 (22:00-06:00), daily cap 20000, `lost_ticket_fee` 15000, timezone America/Bogota, group capacity 20. Lot settings: `pricing_enabled = true`, floor 8000 bps, ceiling 15000 bps, `round_to` 1 unless stated. Rules: R1 "Alta ocupacion" (car, occupancy 80..100, multiplier 12000, priority 200); R2 "Noche valle" (car, 22:00-06:00, multiplier 9000, priority 100); R3 "Evento sabado" (Saturday bit 32, surcharge 2000, multiplier 10000, priority 300). Occupancy = `floor(100 * (open + holds) / 20)`.

1. **Canonical stack (F1, daytime, 85 %).** Entry Wed 09:00, 17 of 20 spaces used so R1 matches (`occupancy_pct 85`), exit 11:30. Base B = 9000 (3 h x 3000). Pricing: `raw = (9000 * 12000 + 5000) / 10000 = 10800`; `lo = 7200`, `hi = 13500`; no clamp; G = 10800 (`delta +1800`). Merchant 50 %: `(10800 * 50 + 50) / 100 = 5400`, R = 5400. Reward fixed 2000: R = 3400. Manual discount 400: `amount_due = 3000`. Stored: `gross_amount = 10800`, two adjustment lines (5400, 2000), `discount_amount = 400`, `amount_charged = 3000`.
2. **Midnight wrap (F2).** Entry Mon 23:00, occupancy 40 % (R1 no); R2 matches (23:00 >= 22:00, `weekdays` null), exit Tue 02:00. B = 6000 (1 + 2 night hours x 2000). `raw = (6000 * 9000 + 5000) / 10000 = 5400`; `lo = 4800`; G = 5400 (`delta -600`). The lock was set at entry, so crossing midnight changes nothing. An entry Tue 01:00 also matches R2 (the `p_local::time < to_time` branch, with Monday's weekday bit, which is null = every day).
3. **Daily cap then multiplier (F3) and the ceiling.** Entry Wed 08:00 at 85 %, exit 18:00. B = 20000 (30000 capped). R1: `raw = 24000`; `hi = (20000 * 15000 + 5000) / 10000 = 30000`; G = 24000 (`delta +4000`, `clamped` null). Ceiling variant: a rule with multiplier 20000 on B = 9000 gives `raw = 18000 > hi = 13500`, so G = 13500 and `clamped = "ceiling"`.
4. **Lost ticket (F6).** The F1 session above (lock R1) is closed as a lost ticket: B = `lost_ticket_amount = greatest(9000, 15000) = 15000`; exclusion 2b, so no pricing (`pricing: null`), G = 15000, merchant validations become `forfeited`; an admin manual discount of 1000 gives `amount_due = 14000`.
5. **Pass holder (F5).** The vehicle has an active pass at the exit date; its session has a lock from an earlier non-pass entry. Exclusion 2a: B = 0, `pricing: null`, `amount_due = 0`, `payment_method = 'monthly_pass'`. Pass sales are never priced.
6. **Surcharge and rounding.** Saturday entry 10:00 at 50 % (R3 only), F1 stay, B = 9000: `raw = (9000 * 10000 + 5000) / 10000 + 2000 = 11000`, in `[7200, 13500]`, step 1: G = 11000 (`kind: "surcharge"`, `delta +2000`). With `round_to = 500`: `((11000 + 250) / 500) * 500 = 11000`. A one-hour stay at 85 % with R1 and `round_to = 500`: `raw = 3600`, `((3600 + 250) / 500) * 500 = 3500`, G = 3500.
7. **Floor.** Same as example 2 with `floor_bps = 9500`: `lo = (6000 * 9500 + 5000) / 10000 = 5700 > raw 5400`, G = 5700 and `clamped = "floor"`.
8. **Offline replay.** (a) Saturday entry 10:00 queued, replayed Sunday 07:00 (older than 5 minutes): R3 gives `pricing_apply(lock, ref 3000) = 5000 > 3000`, so the lock is dropped and G = B. (b) Monday entry 23:00 queued and replayed: R2 gives `2700 <= 3000`, the lock is kept with `source = "offline"`, F2 charges 5400.
9. **Reservation promise.** (a) A public hold booked at 60 % stores the identity lock (the page showed the usual 3000/h). The car arrives at 85 %: current R1 gives 3600/h, held gives 3000/h, held wins, the winner is identity, the session has no lock and F1 charges 9000. (b) A hold booked at 85 % stores the 12000 lock (3600/h); the car arrives at 40 % (no rule): current is the reference 3000/h, which is lower, so the session has no lock.
10. **Floor of zero, stacked.** F1 1-hour stay (B = 3000) at 85 %: G = 3600; merchant fixed 5000 gives `a = 3600`, R = 0; the reward is skipped (`a = 0`, stays available); `amount_due = 0`; the zero charge is explained because the adjustments (3600) equal `gross_amount` (3600).
11. **Free minutes with a lock.** F1 at 85 %, exit 11:30, merchant `free_minutes = 30`: shortened stay ends 11:00, base 6000, priced `raw = 7200` (in `[4800, 9000]`), benefit `= min(10800 - 7200, R) = 3600`; due 7200.

## Trade-offs and rejected alternatives

- **Lock on the session vs recompute at check-out.** Recomputing would charge a price nobody was shown and would make reprints drift; rejected.
- **Trigger vs a new `check_in` parameter.** A shown-price parameter would force dropping the 11-argument overload (trap in `docs/agent-memory.md`), break the offline outbox payload and need a client change in every replayer; the trigger keeps `check_in` byte-identical. The cost is that the price shown a few seconds earlier can differ if another vehicle entered in between; the entry receipt prints the real lock. Accepted.
- **Rule stacking.** Rejected (Decision 3).
- **Rules as percent-only.** A flat surcharge (event nights) is a real request; both kinds are supported and bounded by the same clamp.
- **Occupancy including the entering vehicle.** Rejected: the `BEFORE INSERT` trigger and the check-in preview would disagree; excluding it makes the quote and the lock identical for the same instant.
- **Evaluating occupancy at the offline `entry_time`.** Not reconstructable at replay; the surcharge ban (Decision 7) is the safe alternative.
- **Pricing as a discount line.** Rejected: a surcharge cannot be an "adjustment" (adjustments are reductions and feed the anomaly rule); pricing changes `gross_amount` instead.
- **Putting rules in `tariffs`.** Rejected: `tariffs` is versioned, offline-edited and read by `fare_breakdown`; mixing would couple the cap and night logic with surge rules.
- **A job that recomputes prices every minute.** Rejected: no scheduler is needed; the price is evaluated at the moment it is needed (entry, booking, quote).
- **Versioning the new tables.** Rejected (Decision 11): they are online-only RPC CRUD; adding them to the offline-conflict set would need outbox plumbing nobody uses.

## Open questions for the owner

1. Default floor 100 % and ceiling 150 %, rounding 1: are these the right starting guard rails? Should the lot be allowed a ceiling above 200 %?
2. Should a public hold promise the price shown to the customer even when it is HIGHER than the price at arrival (this design uses the cheaper of the two)?
3. Is the "book cheap, arrive at peak" gain (the hold keeps the cheap price) acceptable, or should holds longer than N hours not lock?
4. Occupancy counts open sessions plus active holds of the group; should reserved-but-not-arrived holds count toward "busy"?
5. Offline check-ins are never surcharged. Is that acceptable commercially, or should the app cache the last quote and honour it?
6. Is one winning rule enough, or does the lot need a "highest of" / "sum" combination later?
7. Should monthly pass renewals (`add-pass-auto-renewal`) ever follow a dynamic price? This design says no.
8. Rounding step: `round_to` applies to the whole stay amount, not per hour; is that what the owner expects for COP (usually multiples of 100)?
