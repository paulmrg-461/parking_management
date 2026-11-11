## Context

Verified against the code (schema head `0103`):

- **Shifts** (`0011`, `lot_id` added by `0023`): `shifts(id bigserial, operator_id, opened_at, closed_at, opening_float, counted_cash, expected_cash, difference, notes, created_at, lot_id)`; one open shift per operator and lot (`uq_open_shift_per_operator`). `close_shift` stores `difference = counted - expected` (`0073`). `shift_adjustments(id, shift_id, old_counted, new_counted, old_difference, new_difference, reason, adjusted_by, adjusted_at)` (`0018`) is written only by `adjust_shift`, which calls `require_admin()` and requires a closed shift.
- **Sessions** (`parking_sessions`): `status` `open|closed`, `entry_time`, `exit_time`, `amount_charged` (net of discount), `payment_method` in `cash|card|transfer|monthly_pass|exempt`, `discount_amount`, `discount_reason`, `discount_by`, `discount_at`, `lost_ticket`, `lost_ticket_reason`, `shift_id`, `operator_id` (the operator who **entered** the vehicle), `closed_recorded_at`, `lot_id`. `check_out` (`0072`) attaches the sale to the **actor's open shift**, so `parking_sessions.shift_id -> shifts.operator_id` is the only record of who closed a sale; it is null when the actor had no open shift.
- **Discounts** exist only as an admin action: `check_out` raises `AdminRequiredError` when `discount > 0` and the caller is not an admin, and `DiscountReasonRequiredError` without a reason.
- **Notifications** (`0008`, `lot_id` by `0023`): `notifications(user_id, type, title, body, data, read_at, pushed_at, push_attempts, dedupe_key unique, created_at, lot_id)`. Writers use `insert ... on conflict (dedupe_key) do nothing` and target admins with `users.role = 'admin' and users.is_active` plus a `lot_members` row (`close_shift`, `notify_overstays`). RLS `notifications_select_own` (`0057`): `user_id = current_app_user_id() and (lot_id is null or can_read_lot(lot_id))`.
- **Audit** (`0031`, `0058`): `audit_log.action` is constrained to `insert|update|delete`; `record_audit()` is a generic row trigger (actor from `auth.uid()`, `lot_id` from the row, entity from the row's `id`, updates keep only changed columns). `list_audit_log` (`0083`) is admin-only (`require_admin()`), filters by table, actor, dates and a search over `entity_id`/`table_name`/actor/plate/name. The audit table's RLS uses `is_admin()` (platform admin).
- **Roles/helpers**: `require_app_user()`, `require_admin()` (`0005`), `current_lot_id()` (`0032`), `is_lot_admin(p_lot_id)` and `require_lot_admin()` returning the lot (`0024`). Admin-only table policy pattern: `pass_payments_admin_read` = `using (public.is_lot_admin(lot_id) and lot_id = public.current_lot_id())`.
- **Jobs**: pg_cron is not installed. `supabase-jobs` in `docker-compose.yml` (`postgres:17-alpine`, `PGUSER=postgres`, entrypoint `/jobs.sh`, `./supabase/jobs.sh:/jobs.sh:ro`) loops every `JOBS_INTERVAL_SECONDS` (300) calling `run <function>` = `psql -tAc "select public.<function>();"` (no arguments, so job functions must have defaults). `supabase/notifications-cron.sh` is the host-cron twin. `0071` only schedules pg_cron when the extension exists. Commit `24a1835` introduced the container.
- Job functions today are granted to `authenticated` (e.g. `notify_overstays`), which lets any user trigger them. New job functions here are **not** granted to any API role.
- Flutter: `AuditPage` is `const AuditPage()` with a hard-coded `_tables` list (`lib/features/audit/presentation/audit_page.dart`); `/audit` is registered in `_homeRoute` without parameters. Notification types are mapped in `notification_routes.dart` and in `notifications_page.dart` (`_typeLabel`, `_iconFor`, the filter menu). Admin destinations live in `managementDestinations` (`lib/app/shell/app_destinations.dart`); `operatorRoutes` in `route_access.dart` is an allowlist, so a new route is admin-only unless added.

### Findings (current code vs the feature idea)

1. **There is no void/cancel-sale operation.** The only post-close correction is `adjust_shift` (admin). The "voids/corrections after close" rule therefore monitors `shift_adjustments`.
2. **There is no manual fare override.** The only price deviation is an admin `discount_amount` with a mandatory reason, and operators cannot create one. The "manual fare overrides / discount rate per operator" rule therefore monitors discounts **per admin** (`discount_by`).
3. **The closing actor is not stored on the session.** Operator attribution goes through `shift_id -> shifts.operator_id`; sessions closed without an open shift are invisible to the per-operator rules (they still feed rules 4, 5 and 6, which key on the session).
4. `exempt` is a payment method any operator can choose at check-out with no reason, which makes it the strongest zero-charge signal; it is flagged, not exempted.
5. `report_revenue`-style `now()`-sensitive code: `now()` is constant inside a transaction (`docs/agent-memory.md`), so ordering by time needs the `id` tiebreaker.

## Goals / Non-Goals

**Goals:** deterministic rules over committed rows; each anomaly raised once; admins notified once per run; operators cannot see anything; every review action audited; rules degrade gracefully when later changes (rewards, validations) are absent.

**Non-Goals:** see `proposal.md`.

## Decisions

1. **Rules are plain SQL functions called by one orchestrator.** `detect_cash_anomalies()` loops the active lots, ensures the settings row, runs eight `anomaly_rule_<name>(p_lot integer, p_cfg anomaly_settings)` functions (each `returns integer`: rows inserted), then notifies. Rejected: one giant statement (unreadable, untestable per rule).
2. **Dedup by `(lot_id, dedupe_key)` unique constraint + `on conflict do nothing`.** The key encodes the subject and, where a recurrence is legitimate, a period or a new triggering row (table below). A dismissed anomaly stays in the table, so it is never re-raised.
3. **Thresholds in `anomaly_settings`, not `parking_settings`.** `settings_read` on `parking_settings` lets every lot member read the row, which would show operators exactly how many shortages they can get away with. A new table with an admin-only policy keeps the thresholds private. Rows are created lazily by `get_anomaly_settings()`/`detect_cash_anomalies()` and backfilled by the migration.
4. **Rolling windows use `now()` and `make_interval`, not business-day math,** except weekly dedupe periods, which use the lot's business timezone ISO week (`to_char(now() at time zone tz, 'IYYY-IW')`).
5. **Notification: one summary per lot per run** (type `cash_anomaly`) for anomalies of severity `medium`/`high` not yet notified. `low` anomalies appear only in the page. The "not yet notified" state is a column (`notified_at`) so the job needs no memory. Rejected: one notification per anomaly (a first run over history could post dozens).
6. **Audit through the generic trigger.** `trg_audit_row` after insert or update on both tables. The detector's inserts are logged with a null actor (system); admin actions with the admin as actor. The audit page link filters `table = cash_anomalies` and searches the anomaly id.
7. **Operators are excluded three ways:** no `select` privilege path (RLS policy requires a lot admin), every RPC calls `require_lot_admin()`, notifications target admins only, and `/anomalies` is not in `operatorRoutes`.
8. **A shift with `difference` null is ignored** (an open shift has none).
9. **Adjustments are anomalies about the adjusted shift's operator**, listing who adjusted; admins reviewing admins is intended (separation of duties).
10. **Rule parameters are integers** (percentages as integer percent, amounts in minor units) so no floating-point comparisons appear in SQL.

## Database

Migration: `supabase/migrations/<NEXT>_cash_anomalies.sql` — use the next free number at implementation time; apply it after `<NEXT>_report_period_comparison.sql`.

### Tables

```sql
create table if not exists public.anomaly_settings (
    id                       serial primary key,
    lot_id                   integer not null unique
                             references public.parking_lots(id) on delete cascade,
    enabled                  boolean not null default true,
    disabled_rules           text[]  not null default '{}',
    window_days              integer not null default 14
        check (window_days between 3 and 90),
    shortage_min_amount      integer not null default 5000
        check (shortage_min_amount between 1 and 100000000),
    shortage_min_shifts      integer not null default 3
        check (shortage_min_shifts between 2 and 20),
    lost_ticket_min_closed   integer not null default 10
        check (lost_ticket_min_closed between 3 and 1000),
    lost_ticket_min_rate_pct integer not null default 10
        check (lost_ticket_min_rate_pct between 1 and 100),
    lost_ticket_factor_pct   integer not null default 200
        check (lost_ticket_factor_pct between 110 and 1000),
    adjustment_min_amount    integer not null default 1000
        check (adjustment_min_amount between 0 and 100000000),
    short_stay_minutes       integer not null default 30
        check (short_stay_minutes between 1 and 720),
    discount_min_count       integer not null default 3
        check (discount_min_count between 1 and 1000),
    discount_share_pct       integer not null default 10
        check (discount_share_pct between 1 and 100),
    shift_open_hours         integer not null default 16
        check (shift_open_hours between 2 and 72),
    session_open_days        integer not null default 7
        check (session_open_days between 1 and 90),
    updated_at               timestamptz not null default now()
);

create table if not exists public.cash_anomalies (
    id              bigserial primary key,
    lot_id          integer not null references public.parking_lots(id) on delete cascade,
    rule            text    not null check (rule in (
        'shift_shortage', 'lost_ticket_rate', 'post_close_adjustment',
        'zero_charge', 'short_lost_ticket', 'discount_rate',
        'shift_open_long', 'session_open_long')),
    severity        text    not null check (severity in ('low', 'medium', 'high')),
    dedupe_key      text    not null,
    subject_user_id integer references public.users(id) on delete set null,
    shift_id        bigint  references public.shifts(id) on delete set null,
    session_id      integer references public.parking_sessions(id) on delete set null,
    details         jsonb   not null default '{}'::jsonb,
    status          text    not null default 'open'
        check (status in ('open', 'acknowledged', 'dismissed')),
    detected_at     timestamptz not null default now(),
    notified_at     timestamptz,
    resolved_by     integer references public.users(id) on delete set null,
    resolved_at     timestamptz,
    note            text check (note is null or char_length(btrim(note)) between 3 and 300),
    constraint cash_anomalies_dedupe unique (lot_id, dedupe_key)
);
create index if not exists ix_cash_anomalies_lot_status
    on public.cash_anomalies (lot_id, status, detected_at desc);
create index if not exists ix_cash_anomalies_unnotified
    on public.cash_anomalies (lot_id) where notified_at is null;
```

Supporting indexes (all `if not exists`; the first duplicates the one from `add-period-comparison-reports` with the same name and definition so the order of the two migrations does not matter):

```sql
create index if not exists ix_sessions_lot_exit_closed
    on public.parking_sessions (lot_id, exit_time) where status = 'closed';
create index if not exists ix_sessions_lot_exit_lost
    on public.parking_sessions (lot_id, exit_time) where lost_ticket;
create index if not exists ix_sessions_lot_exit_discount
    on public.parking_sessions (lot_id, exit_time) where discount_amount > 0;
create index if not exists ix_sessions_lot_exit_zero
    on public.parking_sessions (lot_id, exit_time)
    where status = 'closed' and amount_charged = 0;
create index if not exists ix_shifts_lot_closed
    on public.shifts (lot_id, closed_at) where closed_at is not null;
create index if not exists ix_shifts_lot_open
    on public.shifts (lot_id, opened_at) where closed_at is null;
create index if not exists ix_shift_adjustments_adjusted
    on public.shift_adjustments (adjusted_at desc);
```

(`ix_sessions_open_entry (entry_time) where status = 'open'` from `0001` already serves rule 8.)

### RLS and grants

```sql
alter table public.anomaly_settings enable row level security;
alter table public.cash_anomalies enable row level security;
revoke all on public.anomaly_settings, public.cash_anomalies from anon, authenticated;
grant select on public.anomaly_settings, public.cash_anomalies to authenticated;

drop policy if exists anomaly_settings_admin_read on public.anomaly_settings;
create policy anomaly_settings_admin_read on public.anomaly_settings
    for select to authenticated
    using (public.is_lot_admin(lot_id) and lot_id = public.current_lot_id());

drop policy if exists cash_anomalies_admin_read on public.cash_anomalies;
create policy cash_anomalies_admin_read on public.cash_anomalies
    for select to authenticated
    using (public.is_lot_admin(lot_id) and lot_id = public.current_lot_id());
```

No insert/update/delete grant exists: every write goes through a `security definer` function. The explicit `revoke` matters: Supabase default privileges grant new tables to `anon` (see the gotcha in `docs/agent-memory.md`).

Audit triggers:

```sql
drop trigger if exists trg_audit_row on public.cash_anomalies;
create trigger trg_audit_row after insert or update on public.cash_anomalies
    for each row execute function public.record_audit();
drop trigger if exists trg_audit_row on public.anomaly_settings;
create trigger trg_audit_row after insert or update on public.anomaly_settings
    for each row execute function public.record_audit();
```

Backfill: `insert into public.anomaly_settings (lot_id) select id from public.parking_lots on conflict (lot_id) do nothing;`

### Extension point

```sql
create or replace function public.anomaly_zero_charge_excluded(p_session_id integer)
returns boolean language sql stable set search_path = public
as $$ select false $$;
revoke all on function public.anomaly_zero_charge_excluded(integer)
    from public, anon, authenticated;
```

`add-loyalty-rewards` and `add-merchant-validations` redefine it with `create or replace` (same signature) to return true for sessions whose zero charge is explained by a reward redemption or a merchant validation. Nothing else in this change changes when they land.

### Rules

All rule functions are `security definer`, `set search_path = public`, `revoke all ... from public, anon, authenticated`. `ws` below is `now() - make_interval(days => p_cfg.window_days)`. Every insert is `insert into public.cash_anomalies (lot_id, rule, severity, dedupe_key, subject_user_id, shift_id, session_id, details) ... on conflict (lot_id, dedupe_key) do nothing;` and the function returns `get diagnostics n = row_count`. Subject is the person the anomaly is about.

| # | rule | severity | dedupe key |
|---|---|---|---|
| 1 | `shift_shortage` | `high` when count >= 2 x `shortage_min_shifts`, else `medium` | `shift_shortage:<operator>:<latest short shift id>` |
| 2 | `lost_ticket_rate` | `high` when operator rate >= 3 x baseline (or baseline 0), else `medium` | `lost_ticket_rate:<operator>:<IYYY-IW>` |
| 3 | `post_close_adjustment` | `high` when `old_difference < 0 and new_difference > old_difference`, else `medium` | `post_close_adjustment:<adjustment id>` |
| 4 | `zero_charge` | `high` when method is `cash`/`card`/`transfer` with no discount, else `medium` | `zero_charge:<session id>` |
| 5 | `short_lost_ticket` | `high` | `short_lost_ticket:<session id>` |
| 6 | `discount_rate` | `high` when share >= 3 x `discount_share_pct`, else `medium` | `discount_rate:<admin>:<IYYY-IW>` |
| 7 | `shift_open_long` | `high` when open >= 2 x `shift_open_hours`, else `medium` | `shift_open_long:<shift id>` |
| 8 | `session_open_long` | `medium` when open >= 2 x `session_open_days`, else `low` | `session_open_long:<session id>` |

**1. Repeated shortages.**

```sql
insert into public.cash_anomalies (lot_id, rule, severity, dedupe_key,
                                   subject_user_id, shift_id, details)
select s.lot_id, 'shift_shortage',
       case when count(*) >= p_cfg.shortage_min_shifts * 2 then 'high' else 'medium' end,
       'shift_shortage:' || s.operator_id || ':' || max(s.id),
       s.operator_id, max(s.id),
       jsonb_build_object('shifts', count(*),
                          'total_shortage', -sum(s.difference),
                          'shift_ids', jsonb_agg(s.id order by s.id),
                          'min_amount', p_cfg.shortage_min_amount,
                          'window_days', p_cfg.window_days)
  from public.shifts s
 where s.lot_id = p_lot
   and s.closed_at >= ws
   and s.difference <= -p_cfg.shortage_min_amount
 group by s.lot_id, s.operator_id
having count(*) >= p_cfg.shortage_min_shifts
on conflict (lot_id, dedupe_key) do nothing;
```

Example (defaults: 5000 minor units, 3 shifts, 14 days): operator A closes shifts 41..45 with differences -6000, -5500, 0, -8000, -200. Qualifying: 41, 42, 44 (three) -> one `medium` anomaly keyed `shift_shortage:A:44`, `total_shortage` 19500. The next run produces the same key -> nothing. A fourth short shift 52 later gives key `...:52` -> a new anomaly. With six qualifying shifts the severity becomes `high`.

**2. Lost-ticket rate per operator vs the lot baseline.** Operator attribution through the closing shift:

```sql
with closed as (
    select sh.operator_id, s.lost_ticket
      from public.parking_sessions s
      join public.shifts sh on sh.id = s.shift_id
     where s.lot_id = p_lot and s.status = 'closed' and s.exit_time >= ws
), per_op as (
    select operator_id, count(*) as n, count(*) filter (where lost_ticket) as lost
      from closed group by operator_id
), tot as (
    select sum(n) as n, sum(lost) as lost from per_op
)
insert into public.cash_anomalies (...)
select p_lot, 'lost_ticket_rate',
       case when t.lost - p.lost = 0
              or p.lost * 100 * (t.n - p.n) >= 300 * (t.lost - p.lost) * p.n
            then 'high' else 'medium' end,
       'lost_ticket_rate:' || p.operator_id || ':' || to_char(now() at time zone tz, 'IYYY-IW'),
       p.operator_id, null,
       jsonb_build_object('closed', p.n, 'lost', p.lost,
                          'rate_pct', round(p.lost * 100.0 / p.n, 1),
                          'baseline_pct', round((t.lost - p.lost) * 100.0 / (t.n - p.n), 1),
                          'window_days', p_cfg.window_days)
  from per_op p cross join tot t
 where p.n >= p_cfg.lost_ticket_min_closed
   and t.n > p.n                                         -- needs other operators for a baseline
   and p.lost * 100 >= p_cfg.lost_ticket_min_rate_pct * p.n
   and p.lost * 100 * (t.n - p.n) >= p_cfg.lost_ticket_factor_pct * (t.lost - p.lost) * p.n
on conflict (lot_id, dedupe_key) do nothing;
```

`tz` (here and in rules 6 and 8, written `p_tz` in the sketch) is the lot's `coalesce(business_timezone, 'America/Bogota')`, which each rule function reads itself from `parking_settings where lot_id = p_lot`, so every rule keeps the two-parameter signature `(p_lot integer, p_cfg public.anomaly_settings)`. The last condition is "operator rate >= factor x baseline rate" with the baseline excluding the operator, cross-multiplied to stay in integers.

Example: operator B closed 40 sessions, 8 lost (20 %); the others closed 160, 8 lost (5 %). Min closed 10 ok; 20 % >= 10 % ok; `8*100*160 = 128000 >= 200*8*40 = 64000` ok -> raised; `128000 >= 300*8*40 = 96000` -> severity `high`. With a lot of one operator the rule never fires (no baseline).

**3. Adjustments after close.**

```sql
insert into public.cash_anomalies (...)
select sh.lot_id, 'post_close_adjustment',
       case when sa.old_difference < 0 and sa.new_difference > sa.old_difference
            then 'high' else 'medium' end,
       'post_close_adjustment:' || sa.id, sh.operator_id, sh.id,
       jsonb_build_object('adjustment_id', sa.id, 'old_difference', sa.old_difference,
                          'new_difference', sa.new_difference, 'reason', sa.reason,
                          'adjusted_by', sa.adjusted_by,
                          'adjusted_by_name', u.display_name)
  from public.shift_adjustments sa
  join public.shifts sh on sh.id = sa.shift_id
  left join public.users u on u.id = sa.adjusted_by
 where sh.lot_id = p_lot and sa.adjusted_at >= ws
   and abs(sa.new_difference - sa.old_difference) >= p_cfg.adjustment_min_amount
on conflict (lot_id, dedupe_key) do nothing;
```

Example: shift 41 closed at -6000, an admin corrects the count to -500: `abs(-500 - -6000) = 5500 >= 1000` and the shortage shrank -> `high`.

**4. Zero-amount check-outs that are not passes.**

```sql
insert into public.cash_anomalies (...)
select s.lot_id, 'zero_charge',
       case when s.payment_method in ('cash', 'card', 'transfer')
             and s.discount_amount = 0 then 'high' else 'medium' end,
       'zero_charge:' || s.id, sh.operator_id, s.shift_id, s.id,
       jsonb_build_object('plate', v.plate, 'ticket_number', s.ticket_number,
                          'payment_method', s.payment_method,
                          'discount_amount', s.discount_amount,
                          'discount_reason', s.discount_reason,
                          'exit_time', s.exit_time)
  from public.parking_sessions s
  join public.vehicles v on v.id = s.vehicle_id
  left join public.shifts sh on sh.id = s.shift_id
 where s.lot_id = p_lot and s.status = 'closed' and s.exit_time >= ws
   and s.amount_charged = 0
   and coalesce(s.payment_method, '') <> 'monthly_pass'
   and not public.anomaly_zero_charge_excluded(s.id)
on conflict (lot_id, dedupe_key) do nothing;
```

`exempt` and a fully discounted sale are both reported (they are deliberate zeros that still deserve a second pair of eyes); the discount reason is in `details`.

**5. Lost ticket on a very short stay.**

```sql
 where s.lot_id = p_lot and s.status = 'closed' and s.lost_ticket and s.exit_time >= ws
   and s.exit_time - s.entry_time < make_interval(mins => p_cfg.short_stay_minutes)
```
`details`: plate, `stay_minutes = round(extract(epoch from s.exit_time - s.entry_time) / 60)`, `lost_ticket_reason`, `amount_charged`. Rationale: a lost-ticket fee (`lost_ticket_amount`, `0072`) is at least the lot fee or daily tariff, so charging it on a 4-minute stay is either abuse or a customer being overcharged.

**6. Discount rate per admin.**

```sql
with d as (
    select s.discount_by as admin_id, count(*) as n, sum(s.discount_amount) as amount
      from public.parking_sessions s
     where s.lot_id = p_lot and s.status = 'closed' and s.exit_time >= ws
       and s.discount_amount > 0 and s.discount_by is not null
     group by s.discount_by
), tot as (
    select count(*) as n from public.parking_sessions s
     where s.lot_id = p_lot and s.status = 'closed' and s.exit_time >= ws
)
select ... from d cross join tot t
 where d.n >= p_cfg.discount_min_count
   and d.n * 100 >= p_cfg.discount_share_pct * t.n
```
`details`: `discounts` (d.n), `amount`, `share_pct = round(d.n * 100.0 / t.n, 1)`, `closed_total`. Subject: the admin. Key adds the ISO week. Example: 30 of 200 closed sessions (15 %) discounted by admin C with defaults (3, 10 %): raised `medium`; at 30 % (>= 3 x 10 %) `high`.

**7. Shifts open too long.**

```sql
 from public.shifts s
 where s.lot_id = p_lot and s.closed_at is null
   and s.opened_at < now() - make_interval(hours => p_cfg.shift_open_hours)
```
`details`: `opened_at`, `open_hours = floor(extract(epoch from now() - s.opened_at) / 3600)`, `opening_float`. Subject: `s.operator_id`; shift id set.

**8. Sessions open beyond N days.**

```sql
 from public.parking_sessions s join public.vehicles v on v.id = s.vehicle_id
 where s.lot_id = p_lot and s.status = 'open'
   and s.entry_time < now() - make_interval(days => p_cfg.session_open_days)
   and not exists (select 1 from public.monthly_passes mp
                    where mp.vehicle_id = s.vehicle_id and mp.lot_id = s.lot_id and mp.active
                      and mp.start_date <= (now() at time zone p_tz)::date
                      and mp.end_date   >= (now() at time zone p_tz)::date)
```
`details`: plate, `open_days = floor(extract(epoch from now() - s.entry_time) / 86400)`, `entry_time`. Subject: `s.operator_id` (the operator who checked it in). Vehicles with an active pass are excluded (long stays are normal). This overlaps the overstay *notification* (`overstay_hours`, 24 h by default) on purpose: that is a same-day nudge, this is the persistent review list.

### Orchestrator and notification

```sql
create or replace function public.detect_cash_anomalies()
returns integer language plpgsql security definer set search_path = public as $$
declare
    lot record; cfg public.anomaly_settings%rowtype; tz text;
    created integer := 0; fresh record;
begin
    if not pg_try_advisory_xact_lock(hashtext('detect_cash_anomalies')) then
        return 0;           -- host cron and supabase-jobs overlapped: one run is enough
    end if;
    for lot in select id from public.parking_lots where active loop
        insert into public.anomaly_settings (lot_id) values (lot.id)
            on conflict (lot_id) do nothing;
        select * into cfg from public.anomaly_settings where lot_id = lot.id;
        continue when not cfg.enabled;
        select coalesce(ps.business_timezone, 'America/Bogota') into tz
          from public.parking_settings ps where ps.lot_id = lot.id;
        tz := coalesce(tz, 'America/Bogota');
        if not ('shift_shortage' = any (cfg.disabled_rules)) then
            created := created + public.anomaly_rule_shift_shortage(lot.id, cfg);
        end if;
        -- ... the same guarded call for each of the other seven rules
        select count(*) as total, count(*) filter (where severity = 'high') as high,
               max(id) as last_id
          into fresh
          from public.cash_anomalies
         where lot_id = lot.id and notified_at is null and severity in ('medium', 'high');
        if fresh.total > 0 then
            insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
            select u.id, 'cash_anomaly', 'Anomalías de caja detectadas',
                   fresh.total || ' nuevas (' || fresh.high || ' de severidad alta)',
                   jsonb_build_object('count', fresh.total, 'high', fresh.high,
                                      'last_id', fresh.last_id),
                   'cash_anomaly:' || lot.id || ':' || fresh.last_id || ':user:' || u.id,
                   lot.id
              from public.users u
             where u.is_active
               and exists (select 1 from public.lot_members lm
                            where lm.user_id = u.id and lm.lot_id = lot.id
                              and (u.role = 'admin' or lm.role = 'admin'))
            on conflict (dedupe_key) do nothing;
        end if;
        update public.cash_anomalies set notified_at = now()
         where lot_id = lot.id and notified_at is null;
    end loop;
    return created;
end $$;
revoke all on function public.detect_cash_anomalies() from public, anon, authenticated;
```

`purge_cash_anomalies(p_days integer default 365)` (also revoked from API roles) deletes rows with `status <> 'open'` and `resolved_at < now() - make_interval(days => greatest(p_days, 30))`, and rows still `open` older than 2 x that, returning the count.

### Review RPCs

All four call `require_lot_admin()` (returns the active lot id; raises `AdminRequiredError`, `LotRequiredError`, `InvalidTokenError`), are `security definer`, `set search_path = public`, `revoke all ... from public, anon`, `grant execute ... to authenticated`.

```sql
list_cash_anomalies(p_status text default null, p_rule text default null,
                    p_severity text default null, p_limit integer default 100)
  returns jsonb
```
`p_limit` is clamped to 1..500; an unknown `p_status`/`p_rule`/`p_severity` raises `InvalidDataError`. Order: `detected_at desc, id desc`. Returns:

```json
{
  "open_count": 3,
  "items": [{
    "id": 12, "rule": "shift_shortage", "severity": "medium", "status": "open",
    "detected_at": "2026-11-10T14:05:00Z",
    "operator_id": 7, "operator_name": "María Pérez",
    "shift_id": 44, "session_id": null, "plate": null,
    "details": { "shifts": 3, "total_shortage": 19500 },
    "resolved_at": null, "resolved_by_name": null, "note": null
  }]
}
```
`operator_name` = `users.display_name` of `subject_user_id`; `plate` = `details ->> 'plate'`; `open_count` counts open anomalies of the lot regardless of filters.

```sql
resolve_cash_anomaly(p_id bigint, p_status text, p_note text default null) returns jsonb
```
`p_status` in `acknowledged|dismissed` else `InvalidAnomalyStatusError`; locks the row `for update`; the row must belong to the active lot and be `open`, else `AnomalyNotFoundError` / `AnomalyAlreadyResolvedError`; `dismissed` needs a trimmed note of 3..300 characters else `AnomalyNoteRequiredError`; sets `status`, `resolved_by = require_lot_admin's actor` (`current_app_user_id()`), `resolved_at = now()`, `note`. Returns the item JSON above.

```sql
get_anomaly_settings() returns jsonb          -- inserts the default row if missing
set_anomaly_settings(p_settings jsonb) returns jsonb
```
`set_anomaly_settings` accepts a JSON object whose keys are column names of `anomaly_settings` (except `id`, `lot_id`, `updated_at`); a missing key keeps the value; an unknown key, a non-integer for an integer column, or a violated range raises `InvalidAnomalySettingError` (check the range in the function before updating so the error is typed instead of `23514`); `disabled_rules` must be an array of known rule names. Returns the settings JSON with the same snake_case keys.

### Scheduling

- `supabase/jobs.sh`: after `run notify_expiring_reservations` add `run detect_cash_anomalies` and after `run purge_whatsapp_messages` add `run purge_cash_anomalies`. The loop runs them every `JOBS_INTERVAL_SECONDS` (300 s); each rule is idempotent and bounded by indexes, and the advisory lock prevents overlap with the host cron. Apply with `docker compose restart supabase-jobs`.
- `supabase/notifications-cron.sh`: add the two equivalent `docker compose exec -T db psql ... "select public.detect_cash_anomalies();"` lines (the script already uses `set -eu`).
- `0071`-style pg_cron scheduling is deliberately not added: the shipped image has no pg_cron.

### Performance

Per lot per run: rules 1, 3, 7 touch tens of rows; rules 2, 4, 5, 6 scan `parking_sessions` for `window_days` (14 days ~ 4 000 closed sessions at 300/day) through `ix_sessions_lot_exit_closed` or the partial indexes above, plus a primary-key join to `shifts`; rule 8 scans only open sessions. Expected total well under 100 ms per lot; the `authenticated` 15 s `statement_timeout` (`0074`) does not apply to the job (`postgres`) and the review RPCs read at most 500 rows by `ix_cash_anomalies_lot_status`.

## Flutter

### File tree

```
lib/features/anomalies/
├── domain/
│   ├── entities/cash_anomaly.dart            NEW  (CashAnomaly, AnomalyList, AnomalyRule, AnomalySeverity, AnomalyStatus)
│   ├── entities/anomaly_settings.dart        NEW
│   └── repositories/anomaly_repository.dart  NEW
├── application/anomalies_cubit.dart          NEW
├── infrastructure/
│   ├── anomaly_remote_data_source.dart       NEW
│   └── anomaly_repository_impl.dart          NEW
└── presentation/
    ├── anomalies_page.dart                   NEW
    └── widgets/
        ├── anomaly_tile.dart                 NEW
        ├── anomaly_resolve_dialog.dart       NEW
        └── anomaly_settings_sheet.dart       NEW
lib/app/di/modules/anomalies_module.dart      NEW   (registerAnomaliesModule)
```

Modified: `lib/app/di/injection.dart` (call `registerAnomaliesModule(sl)` in `registerAllModules`), `lib/app/router/app_router.dart` (route `anomalies` under `_homeRoute`, next to `audit`; pass `table`/`search` query parameters to `AuditPage`), `lib/app/shell/app_destinations.dart` (new `_anomalies` label + `AppDestination('/anomalies', _anomalies, Icons.report_problem_outlined, Icons.report_problem)` in `managementDestinations`), `lib/features/audit/presentation/audit_page.dart` (`const AuditPage({super.key, this.initialTable, this.initialSearch})`, add `cash_anomalies` and `anomaly_settings` to `_tables`, first load uses the initial values), `lib/features/notifications/presentation/notification_routes.dart` (`'cash_anomaly' => '/anomalies'`), `lib/features/notifications/presentation/notifications_page.dart` (filter entry, `_typeLabel`, `_iconFor` → `Icons.report_problem_outlined`), `lib/core/l10n/failure_messages.dart` (four new codes), `lib/l10n/app_es.arb` / `app_en.arb`.

`/anomalies` is NOT added to `operatorRoutes`: operators are redirected home by `authRedirect`.

### Domain

```dart
enum AnomalyRule { shiftShortage, lostTicketRate, postCloseAdjustment, zeroCharge,
                   shortLostTicket, discountRate, shiftOpenLong, sessionOpenLong }
// wire names: shift_shortage, lost_ticket_rate, post_close_adjustment, zero_charge,
//             short_lost_ticket, discount_rate, shift_open_long, session_open_long
enum AnomalySeverity { low, medium, high }
enum AnomalyStatus { open, acknowledged, dismissed }

class CashAnomaly extends Equatable {
  final int id;
  final AnomalyRule rule;             // unknown wire name -> skipped by AnomalyList.fromJson
  final AnomalySeverity severity;
  final AnomalyStatus status;
  final DateTime detectedAt;
  final int? operatorId;
  final String? operatorName;
  final int? shiftId;
  final int? sessionId;
  final String? plate;
  final Map<String, dynamic> details;
  final DateTime? resolvedAt;
  final String? resolvedByName;
  final String? note;
  bool get isOpen => status == AnomalyStatus.open;
  factory CashAnomaly.fromJson(Map<String, dynamic> json);
}

class AnomalyList extends Equatable {
  const AnomalyList({this.items = const [], this.openCount = 0});
  static const empty = AnomalyList();
  final List<CashAnomaly> items;
  final int openCount;
}

class AnomalySettings extends Equatable {   // 13 integer/bool fields mirroring the table
  final bool enabled; final Set<AnomalyRule> disabledRules;
  final int windowDays, shortageMinAmount, shortageMinShifts, lostTicketMinClosed,
      lostTicketMinRatePct, lostTicketFactorPct, adjustmentMinAmount, shortStayMinutes,
      discountMinCount, discountSharePct, shiftOpenHours, sessionOpenDays;
  Map<String, dynamic> toJson();           // only the keys set_anomaly_settings accepts
  factory AnomalySettings.fromJson(Map<String, dynamic> json);
  static const defaults = AnomalySettings(...); // the SQL defaults
}
```

Port:

```dart
abstract class AnomalyRepository {
  Future<AnomalyList> list({AnomalyStatus? status, AnomalyRule? rule, AnomalySeverity? severity});
  Future<CashAnomaly> resolve({required int id, required AnomalyStatus status, String? note});
  Future<AnomalySettings> loadSettings();
  Future<AnomalySettings> saveSettings(AnomalySettings settings);
}
```

The data source calls `list_cash_anomalies` (`p_status`, `p_rule`, `p_severity`), `resolve_cash_anomaly` (`p_id`, `p_status`, `p_note`), `get_anomaly_settings`, `set_anomaly_settings` (`p_settings`), each in `try { ... } catch (error) { throw mapSupabaseError(error); }`. The repository is remote-only (no outbox: reviewing is an admin online action, like shift actions).

### Application

`AnomaliesCubit extends ResilientCubit<AnomaliesState>`; sealed `Equatable` states:

- `AnomaliesInitial`.
- `AnomaliesLoading` (skeleton).
- `AnomaliesLoaded(list, {status = AnomalyStatus.open, rule, severity, resolvingId, notice})` — success **and** empty (`list.items.isEmpty` → the page shows the empty state; with a non-default filter the empty state offers "Limpiar filtros").
- `AnomaliesFailure(message, {failure})` with retry.

Methods: `load({AnomalyStatus? status, AnomalyRule? rule, AnomalySeverity? severity, bool clearFilters = false})` (keeps previous filters like `AuditCubit`; the default status filter is `open`), `resolve({required int id, required AnomalyStatus status, String? note})` (sets `resolvingId`, calls the repository, then reloads with the same filters; on `Failure` emits loaded with `notice` = failure so the dialog can show it and keeps the list), `loadSettings()` / `saveSettings(AnomalySettings)` used by the sheet through a small `Future` returning API (the sheet owns its own transient state; failures return a `Failure`).

### Presentation

`AnomaliesPage` (route `/anomalies`): `Scaffold` + `AppBar(title: l10n.anomaliesTitle)` with an `AppIconButton(icon: Icons.tune, tooltip: l10n.anomaliesSettings)` and `EmergencyAction`-style actions consistent with `AuditPage`; body = `FilterBar` (status `ChoiceChip`s open/acknowledged/dismissed/all — up to five choices stay chips; rule and severity `DropdownButtonFormField`s because rules are eight; `summary: l10n.anomaliesOpenCount(openCount)`; `onClear`), then the list. Four states: `SkeletonCardList` (loading), `ListView` of `AnomalyTile` (success), `EmptyState(icon: Icons.verified_outlined, title: l10n.anomaliesEmptyTitle, message: l10n.anomaliesEmpty)` (empty), `ErrorState(message: l10n.errorText(...), onRetry: load)` (error). Pull-to-refresh via `RefreshIndicator`.

`AnomalyTile`: severity `StatusChip` (high = `StatusTone.warning` with `Icons.priority_high`, medium = `pending`, low = `neutral`; the red semantic colour is reserved for actionable anomalies per AGENTS §3, so `high` uses `colorScheme.error` through the chip's warning tone only if the design system maps it; do not hard-code), title = localized rule name, subtitle = localized one-line description built from `details` (see l10n), operator name, `DateTimeText(detectedAt)`; status chip when resolved with the resolver and note. Actions (each an `AppIconButton`/`TextButton`, >= 48 dp): **Reconocer** and **Descartar** (open only) → `AnomalyResolveDialog` (note field, required for dismiss, 3..300 characters, `textCapitalization.sentences`, `AlertDialog(scrollable: true)`), **Ver auditoría** → `context.go('/audit?table=cash_anomalies&search=<id>')`, and a context link: session anomalies with a plate → `/history?plate=<plate>`; shift anomalies → `/shift` (the shift history, admin view; there is no per-shift deep link today). Plates use `PlateText`; money uses `Formatters.money` / `Money`.

`AnomalySettingsSheet`: bottom sheet (`MediaQuery.viewInsetsOf(context).bottom` padding) with the thresholds as validated numeric fields (ranges identical to the SQL checks, shown as helper text), a master switch and one `SwitchListTile` per rule; save disabled while invalid; a server `InvalidAnomalySettingError` shows inline.

### DI (`anomalies_module.dart`)

```dart
void registerAnomaliesModule(GetIt sl) {
  sl
    ..registerLazySingleton<AnomalyRemoteDataSource>(() => SupabaseAnomalyRemoteDataSource(sl<SupabaseClient>()))
    ..registerLazySingleton<AnomalyRepository>(() => AnomalyRepositoryImpl(sl<AnomalyRemoteDataSource>()))
    ..registerFactory<AnomaliesCubit>(() => AnomaliesCubit(sl<AnomalyRepository>()));
}
```

### l10n keys (ES / EN; add to both ARB files, then `flutter gen-l10n`; grep for duplicates first)

| key | ES | EN |
|---|---|---|
| `navAnomalies` | Anomalías | Anomalies |
| `anomaliesTitle` | Anomalías de caja | Cash anomalies |
| `anomaliesSettings` | Umbrales | Thresholds |
| `anomaliesOpenCount` (`{count}` int) | {count} abiertas | {count} open |
| `anomaliesStatusOpen` / `Acknowledged` / `Dismissed` / `All` | Abiertas / Reconocidas / Descartadas / Todas | Open / Acknowledged / Dismissed / All |
| `anomaliesRuleLabel` / `anomaliesSeverityLabel` | Regla / Severidad | Rule / Severity |
| `anomaliesSeverityLow` / `Medium` / `High` | Baja / Media / Alta | Low / Medium / High |
| `anomalyRuleShiftShortage` | Faltantes repetidos | Repeated shortages |
| `anomalyRuleLostTicketRate` | Tasa alta de ticket perdido | High lost-ticket rate |
| `anomalyRulePostCloseAdjustment` | Ajuste después del cierre | Adjustment after close |
| `anomalyRuleZeroCharge` | Salida sin cobro | Check-out with no charge |
| `anomalyRuleShortLostTicket` | Ticket perdido con estadía corta | Lost ticket on a short stay |
| `anomalyRuleDiscountRate` | Descuentos frecuentes | Frequent discounts |
| `anomalyRuleShiftOpenLong` | Turno abierto demasiado tiempo | Shift open too long |
| `anomalyRuleSessionOpenLong` | Vehículo dentro por muchos días | Vehicle inside for many days |
| `anomalyDescShiftShortage` (`{count}` int, `{amount}` String) | {count} turnos con faltante, total {amount} | {count} short shifts, total {amount} |
| `anomalyDescLostTicketRate` (`{rate}` String, `{baseline}` String) | {rate} % de tickets perdidos frente a {baseline} % de la sede | {rate}% lost tickets against {baseline}% for the site |
| `anomalyDescPostCloseAdjustment` (`{from}`, `{to}`, `{admin}` String) | Diferencia {from} → {to} ajustada por {admin} | Difference {from} → {to} adjusted by {admin} |
| `anomalyDescZeroCharge` (`{plate}`, `{method}` String) | {plate} salió sin cobro ({method}) | {plate} left with no charge ({method}) |
| `anomalyDescShortLostTicket` (`{plate}` String, `{minutes}` int) | {plate}: ticket perdido tras {minutes} min | {plate}: lost ticket after {minutes} min |
| `anomalyDescDiscountRate` (`{count}` int, `{share}` String) | {count} descuentos ({share} % de las salidas) | {count} discounts ({share}% of exits) |
| `anomalyDescShiftOpenLong` (`{hours}` int) | Abierto desde hace {hours} h | Open for {hours} h |
| `anomalyDescSessionOpenLong` (`{plate}` String, `{days}` int) | {plate} lleva {days} días dentro | {plate} has been inside for {days} days |
| `anomalyAcknowledge` | Reconocer | Acknowledge |
| `anomalyDismiss` | Descartar | Dismiss |
| `anomalyNoteLabel` | Nota | Note |
| `anomalyNoteRequired` | Escribe una nota de al menos 3 caracteres | Write a note of at least 3 characters |
| `anomalyViewAudit` | Ver auditoría | View audit trail |
| `anomalyViewContext` | Ver detalle | View details |
| `anomaliesEmptyTitle` | Todo en orden | All clear |
| `anomaliesEmpty` | No hay anomalías con estos filtros. | No anomalies match these filters. |
| `anomaliesSettingsEnabled` | Detección activa | Detection enabled |
| `anomaliesSettingsSaved` | Umbrales guardados | Thresholds saved |
| `notifTypeCashAnomaly` | Anomalía de caja | Cash anomaly |
| `errorAnomalyNotFound` | No encontramos esa anomalía | We could not find that anomaly |
| `errorAnomalyAlreadyResolved` | Esa anomalía ya fue revisada | That anomaly was already reviewed |
| `errorAnomalyNoteRequired` | Escribe una nota de al menos 3 caracteres | Write a note of at least 3 characters |
| `errorInvalidAnomalySetting` | Revisa los valores de los umbrales | Check the threshold values |

Threshold field labels use one key each, `anomaliesSettings<Field>` (`WindowDays`, `ShortageMinAmount`, `ShortageMinShifts`, `LostTicketMinClosed`, `LostTicketMinRatePct`, `LostTicketFactorPct`, `AdjustmentMinAmount`, `ShortStayMinutes`, `DiscountMinCount`, `DiscountSharePct`, `ShiftOpenHours`, `SessionOpenDays`) with ES labels such as "Ventana (días)" and EN "Window (days)"; the implementer writes the 12 pairs following the SQL column names. `FailureMessages._byCode` maps `AnomalyNotFoundError`, `AnomalyAlreadyResolvedError`, `AnomalyNoteRequiredError`, `InvalidAnomalySettingError` (and `InvalidAnomalyStatusError` to `errorInvalidData`). The notification text itself is written in Spanish by SQL, like the other notification types.

### Offline behaviour

Remote-only. Offline, the page shows the error state with retry. The notification inbox keeps showing already delivered `cash_anomaly` rows through its own cache. No dashboard cache change.

## Security

| Actor | `cash_anomalies` / `anomaly_settings` select | RPCs | Notification | `/anomalies` |
|---|---|---|---|---|
| `anon` | no grant | revoked | none | redirected to login |
| operator (not lot admin) | RLS returns 0 rows | `AdminRequiredError` | never created for them | redirected home |
| lot admin / admin of the active lot | own lot only | allowed | receives the summary | allowed |
| admin with a foreign `x-lot-id` | `LotRequiredError` from `current_lot_id()` | same | n/a | n/a |

- Job functions (`detect_cash_anomalies`, `purge_cash_anomalies`, the `anomaly_rule_*` functions, `anomaly_zero_charge_excluded`) are revoked from `public`, `anon` and `authenticated`; only `postgres`/`service_role` can run them. This is stricter than the existing job functions on purpose.
- Lot isolation: rules filter `lot_id = p_lot`; review RPCs use the validated `current_lot_id()`.
- `details` contains plates and names; both tables are admin-only and the notification body has only counts.
- Separation of duties: `post_close_adjustment` and `discount_rate` report admin actions to admins; there is no role above lot admin, so the audit log (platform admin) is the second line.
- Acknowledge/dismiss and settings changes are audited with the actor (`audit_log` rows for `cash_anomalies` / `anomaly_settings`).

## Risks / Trade-offs

- [False positives] A rolling shortage count can flag an honest operator; severity and the review workflow (acknowledge/dismiss with note) are the control, thresholds are tunable per lot.
- [First run floods history] The first execution inspects `window_days` of history (up to 90): one summary notification per lot, not one per anomaly.
- [Attribution gaps] Sessions closed without an open shift have no operator for rules 2 (documented, Findings 3).
- [Lost-ticket baseline needs two operators] Single-operator lots get no rule 2 findings by design.
- [`exempt` flagged] Admins who legitimately use `exempt` will see recurring `medium` findings; the extension point and `disabled_rules` exist for that.
- [Job overlap] `pg_try_advisory_xact_lock` makes the second concurrent run a no-op.

## Migration Plan

1. Apply `<NEXT>_cash_anomalies.sql` (additive; backfills one settings row per lot).
2. Edit `supabase/jobs.sh` and `notifications-cron.sh`, then `docker compose restart supabase-jobs`.
3. Ship the Flutter build. Until the jobs run nothing is detected; until the app ships nothing is shown.
4. Rollback: remove the two `run` lines, then `drop table public.cash_anomalies, public.anomaly_settings cascade;` and drop the functions. Notifications already delivered stay (type `cash_anomaly` falls back to the generic label).

## Open Questions

1. Which defaults does the owner want (14 days, 3 short shifts of 5000, 10 % lost-ticket rate at 2x the baseline, 30-minute short stay, 16 h shifts, 7 days sessions)? The shortage default is in minor units: 5000 is `$5.000` in COP but `US$50.00` in USD, so USD lots should lower it.
2. Should `exempt` check-outs be excluded from `zero_charge` until the owner introduces a reason for them?
3. Should low-severity anomalies ever notify?
4. Should the audit link also work for lot admins who are not platform admins? Today `audit_log` RLS is `is_admin()` (platform admin only).
5. Is a per-shift deep link (`/shift?shift=<id>`) wanted? It needs a change to `ShiftPage`.
