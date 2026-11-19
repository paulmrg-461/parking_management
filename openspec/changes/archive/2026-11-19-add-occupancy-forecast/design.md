## Context

Verified against the code (schema head `0103`):

- **History source:** `parking_sessions(id, vehicle_id, operator_id, entry_time, exit_time, status, lot_id, ...)`; `vehicles.category_id -> categories(id, name, lot_id, capacity)`. `public.category_group(p_name)` (`0058`, immutable) maps a category name to `car` (`car`, `carro`, `auto`, `camioneta`, `suv`), `moto` (`moto`, `motos`, `motorcycle`) or `heavy`. The same join is used by `capacity_snapshot` (`0061`) and `public_availability` (`0101`).
- **Capacity per group** is derived in two places today, with the same rule: if the lot has `parking_spots` of that group, capacity = active spots; otherwise `public.usable_capacity(parking_settings.<group>_capacity, <group>_out_of_service)` (`0054`; `car_capacity`/`moto_capacity` are columns of `parking_settings`, `0047`). `heavy` has no capacity. There is no reusable function, so this change adds `public.group_capacity(p_lot, p_group)` without refactoring the existing ones.
- **Occupancy (live)** = count of `status = 'open'` sessions of the lot (`capacity_snapshot.car_open`, `public_availability.occupied`). Reservation holds (`category_reservations`) are separate and are not part of occupancy.
- **Business timezone:** `coalesce(parking_settings.business_timezone, 'America/Bogota')` (`0005`); public RPCs use `coalesce(settings.business_timezone, lot.timezone, 'America/Bogota')`.
- **`public_availability(p_lot_id integer)`** latest body: `0101_branding_cover.sql` (`security definer`, `stable`, granted to `anon, authenticated`; returns `null` for an unknown or inactive lot; keys `lot`, `max_reservation_hours`, `categories[]`). `0103` (captcha, in progress) does not redefine it. Later changes in the global order (waitlist, dynamic pricing, payments) may. The anon role has `statement_timeout = 5 s` (`0074`).
- **Jobs:** `supabase/jobs.sh` (container `supabase-jobs`) runs `psql -tAc "select public.<fn>();"` every 300 s; functions need default arguments; pg_cron is not available.
- **Flutter:** `DashboardCubit._fetch` (`lib/features/home/application/dashboard_cubit.dart`) runs `todaySummary`, `dashboardTrend(days: 14)`, `capacitySnapshot`, `slotBoard`, `_inside()` and `lotSetup` in one record `.wait`, each with its own `catchError`; `complete` turns false only when a cached KPI failed. `DashboardSnapshot` (schema version 1) caches occupancy, today, trend and capacity; on a stale load the board and inside list are hidden. All dashboard RPCs live behind `CheckOutRepository` / `CheckOutRemoteDataSource` (`dashboardTrend`, `lotSetup`). `PublicBookingAvailability.fromJson` (`lib/features/public_booking/domain/entities/public_booking.dart`) parses `lot`, `max_reservation_hours` and `categories`. `ReportsLoaded` and `ReportsCubit` are in `lib/features/reports/application/reports_cubit.dart`.

### Findings (current code vs the feature idea)

1. **There is no occupancy history table.** Net occupancy must be reconstructed from entry/exit timestamps; stuck-open sessions (never closed) would distort it, so the reconstruction caps any stay at 72 h.
2. **Capacity logic is duplicated** (`capacity_snapshot`, `public_availability`); this change adds a third reader (`group_capacity`) rather than refactor two published RPCs.
3. **Reservations are outside occupancy,** so a lot can be "available" in the forecast while its remaining bays are held. The public page already shows `reserved` per category; the forecast does not account for holds (documented limitation).
4. `public_availability` is edited by several changes in the global order; copying its body again would silently revert them. The wrapper approach below avoids that.
5. `now()` is constant inside a transaction (`docs/agent-memory.md`): the compute function takes an explicit `p_now` so tests are deterministic.

## Goals / Non-Goals

**Goals:** a forecast anyone can verify by hand; the same number everywhere (home, public page, backtest); nothing shown when the data cannot support it; no session-level data to anonymous callers.

**Non-Goals:** see `proposal.md`.

## Decisions

1. **Statistic: median of the last K same-weekday observations** (K = `history_weeks`, default 8, 4..26). Median over trimmed mean because one holiday, an event or a broken-gate day is an outlier that a mean absorbs by 1/K and a median ignores entirely; K = 8 tolerates up to 3 outliers. No tuning parameter, one `percentile_cont(0.5)`.
2. **Observation = occupancy at each full hour mark** (`HH:00` business time) of a past date: the number of sessions with `entry_time <= mark < exit_time` per group. Hourly marks give 24 observations a day, enough to see a 6 pm peak, and make the "net occupancy from entries and exits" definition exact: `occupancy(mark) = entries up to mark - exits up to mark`.
3. **Observation dates are the 7 x K completed days before today** (never today), so each weekday has exactly K dates. Dates before the lot's first session are excluded, which is what makes the minimum-history rule work for new lots.
4. **Minimum history:** a profile cell with fewer than `min_samples` (default 4, 3..K) observations is unusable. A group is forecast only if every cell it needs (the current hour, the next one and the next 12 hours) is usable; otherwise the group is omitted and, if all groups are omitted, the status is `insufficient_history`.
5. **Blend:** `forecast(m) = profile(m) + (live - profile_now) * w^a`, with `w = blend_decay_pct / 100` (default 0.85), `a` = hours from now to mark `m`, `profile_now` = linear interpolation of the profile between the current hour mark and the next. The live deviation fades by 15 % per hour. Clamped to `[0, capacity]` for display; the unclamped value decides "full". Rejected: exponential smoothing / regression (more parameters, harder to explain to the owner), dampening toward the last observation only (ignores the weekly shape).
6. **"Full" = unclamped forecast >= `capacity * full_threshold_pct / 100`** (default 100 %). `full_at` is the linear interpolation between the live point (now, `live`) and the hourly points, rounded to the nearest 15 minutes and printed `HH:mm` in business time. `full_now` is true when `live` is already at or above the threshold. No crossing in the horizon -> `full_at = null`.
7. **Confidence from sample size only** (the brief's rule): the minimum `samples` over the cells used. `high` >= 7, `medium` 5..6, `low` below 5 (but at least `min_samples`).
8. **Materialisation:** the profile (`occupancy_profile`, at most 3 groups x 7 x 24 = 504 rows per lot) is rebuilt by `refresh_occupancy_profile()` when older than 6 hours, so the request path never touches `parking_sessions` history; the only live query is the open-session count.
9. **Holidays: out of scope.** Alternative considered: an admin-maintained `forecast_exceptions(lot_id, date, note)` list excluded from the observations (and, for today, switching to a "holiday profile"). Rejected for v1: the median already neutralises isolated holidays; a holiday today is corrected by the live blend within hours; a calendar needs maintenance and a UI that the owner has not asked for, and national calendars differ. If the owner wants it, the extension is a table plus one `and not exists (...)` in `occupancy_grid` consumers; recorded as an open question.
10. **Public exposure is aggregate-only and bucketed:** per group `full_at`, `full_now`, `confidence` and 12 `level` values (`free` < 80 % of capacity, `busy` 80 % up to the full threshold, `full`). No counts, capacities, samples or timestamps of vehicles. Occupancy counts are already public per category (`occupied`), so levels reveal nothing new, but bucketing keeps the contract narrow.
11. **`public_availability` becomes a wrapper:** rename the current function to `public_availability_base` (same body, privileges revoked from API roles) and create a new `public_availability(integer)` that returns `base || {"forecast": ...}`. Later changes must edit `public_availability_base`. The forecast block can never break booking: any error inside it returns `{"status":"unavailable","groups":[]}`.
12. **Public visibility defaults to on** (`public_enabled = true`) because there is no settings UI in this change; a lot admin turns it off with `set_forecast_settings('{"public_enabled": false}')`. Recorded as an open question.

## Database

Migration: `supabase/migrations/<NEXT>_occupancy_forecast.sql` — use the next free number at implementation time.

### Tables

```sql
create table if not exists public.forecast_settings (
    id                 serial primary key,
    lot_id             integer not null unique
                       references public.parking_lots(id) on delete cascade,
    enabled            boolean not null default true,
    history_weeks      integer not null default 8  check (history_weeks between 4 and 26),
    min_samples        integer not null default 4  check (min_samples between 3 and 26),
    blend_decay_pct    integer not null default 85 check (blend_decay_pct between 50 and 99),
    full_threshold_pct integer not null default 100 check (full_threshold_pct between 50 and 100),
    public_enabled     boolean not null default true,
    updated_at         timestamptz not null default now(),
    constraint forecast_settings_samples_check check (min_samples <= history_weeks)
);

create table if not exists public.occupancy_profile (
    lot_id           integer  not null references public.parking_lots(id) on delete cascade,
    group_name       text     not null check (group_name in ('car', 'moto', 'heavy')),
    dow              smallint not null check (dow between 0 and 6),   -- extract(dow): 0 = Sunday
    hour             smallint not null check (hour between 0 and 23),
    median_occupancy numeric(8, 2) not null check (median_occupancy >= 0),
    samples          smallint not null check (samples >= 0),
    computed_at      timestamptz not null default now(),
    primary key (lot_id, group_name, dow, hour)
);
```

RLS and grants:

```sql
alter table public.forecast_settings enable row level security;
alter table public.occupancy_profile enable row level security;
revoke all on public.forecast_settings, public.occupancy_profile from anon, authenticated;
grant select on public.forecast_settings, public.occupancy_profile to authenticated;

create policy forecast_settings_admin_read on public.forecast_settings
    for select to authenticated
    using (public.is_lot_admin(lot_id) and lot_id = public.current_lot_id());
create policy occupancy_profile_member_read on public.occupancy_profile
    for select to authenticated
    using (lot_id = public.current_lot_id());
```

(Staff and operators may read the profile of their active lot: it is an aggregate used by the home card. `anon` has no grant.) `forecast_settings` gets the audit trigger: `create trigger trg_audit_row after insert or update on public.forecast_settings for each row execute function public.record_audit();` (`record_audit` takes `lot_id` from the row and the entity id from `id`). Backfill: `insert into public.forecast_settings (lot_id) select id from public.parking_lots on conflict (lot_id) do nothing;`.

### Internal helpers (all `revoke all ... from public, anon, authenticated`)

```sql
-- Capacity of one group: active bays when the lot drew any, else usable settings capacity.
create or replace function public.group_capacity(p_lot integer, p_group text)
returns integer language sql stable security definer set search_path = public as $$
    select case
        when exists (select 1 from public.parking_spots sp
                      where sp.lot_id = p_lot and sp.group_name = p_group)
            then (select count(*)::integer from public.parking_spots sp
                   where sp.lot_id = p_lot and sp.group_name = p_group and sp.status = 'active')
        when p_group = 'car' then public.usable_capacity(
            (select ps.car_capacity from public.parking_settings ps where ps.lot_id = p_lot),
            (select ps.car_out_of_service from public.parking_settings ps where ps.lot_id = p_lot))
        when p_group = 'moto' then public.usable_capacity(
            (select ps.moto_capacity from public.parking_settings ps where ps.lot_id = p_lot),
            (select ps.moto_out_of_service from public.parking_settings ps where ps.lot_id = p_lot))
        else 0 end;
$$;
```

```sql
-- Net occupancy at every full hour of every date in [p_from, p_to], per group,
-- in the lot's business timezone. Quiet slots are returned as 0.
create or replace function public.occupancy_grid(p_lot integer, p_from date, p_to date)
returns table (group_name text, day date, hour integer, occupancy integer)
language sql stable security definer set search_path = public as $$
    with tz as (
        select coalesce((select ps.business_timezone from public.parking_settings ps
                          where ps.lot_id = p_lot), 'America/Bogota') as name
    ), groups as (
        select distinct public.category_group(c.name) as g
          from public.categories c where c.lot_id = p_lot
    ), slots as (
        select g.g, d::date as day, h
          from groups g,
               generate_series(p_from::timestamp, p_to::timestamp, interval '1 day') d,
               generate_series(0, 23) h
    ), marks as (
        select public.category_group(c.name) as g, m as mark
          from public.parking_sessions s
          join public.vehicles v on v.id = s.vehicle_id
          join public.categories c on c.id = v.category_id
          cross join tz
          cross join lateral (
              select s.entry_time at time zone tz.name as e,
                     least(coalesce(s.exit_time, now()), s.entry_time + interval '72 hours')
                         at time zone tz.name as x
          ) t
          cross join lateral generate_series(
              date_trunc('hour', t.e)
                  + case when t.e = date_trunc('hour', t.e) then interval '0' else interval '1 hour' end,
              t.x - interval '1 microsecond',
              interval '1 hour') m
         where s.lot_id = p_lot
           and s.entry_time >= p_from::timestamp at time zone tz.name - interval '72 hours'
           and s.entry_time <  (p_to + 1)::timestamp at time zone tz.name
           and m >= p_from::timestamp and m < (p_to + 1)::timestamp
    ), counted as (
        select g, mark::date as day, extract(hour from mark)::integer as hour, count(*) as n
          from marks group by 1, 2, 3
    )
    select s.g, s.day, s.h, coalesce(c.n, 0)::integer
      from slots s
      left join counted c on c.g = s.g and c.day = s.day and c.hour = s.h;
$$;
```

The `entry_time >= p_from - 72 h` and `entry_time < end` predicates make the scan a range scan on `ix_sessions_lot_entry (lot_id, entry_time desc)` from `0069_scale_hardening.sql`; no new index is needed. A group is attributed by the vehicle's current category name.

### Profile refresh

```sql
create or replace function public.refresh_occupancy_profile(p_force boolean default false)
returns integer language plpgsql security definer set search_path = public as $$
declare lot record; tz text; today date; k integer; first_day date; written integer := 0; n integer;
begin
    if not pg_try_advisory_xact_lock(hashtext('refresh_occupancy_profile')) then return 0; end if;
    for lot in
        select l.id, coalesce(fs.history_weeks, 8) as weeks
          from public.parking_lots l
          left join public.forecast_settings fs on fs.lot_id = l.id
         where l.active and coalesce(fs.enabled, true)
    loop
        continue when not p_force and exists (
            select 1 from public.occupancy_profile p
             where p.lot_id = lot.id and p.computed_at > now() - interval '6 hours');
        select coalesce(ps.business_timezone, 'America/Bogota') into tz
          from public.parking_settings ps where ps.lot_id = lot.id;
        tz := coalesce(tz, 'America/Bogota');
        today := (now() at time zone tz)::date;
        select (min(s.entry_time) at time zone tz)::date into first_day
          from public.parking_sessions s where s.lot_id = lot.id;
        continue when first_day is null;
        insert into public.occupancy_profile
               (lot_id, group_name, dow, hour, median_occupancy, samples, computed_at)
        select lot.id, g.group_name, extract(dow from g.day)::integer, g.hour,
               round((percentile_cont(0.5) within group (order by g.occupancy))::numeric, 2),
               count(*), now()
          from public.occupancy_grid(lot.id, today - 7 * lot.weeks, today - 1) g
         where g.day >= first_day
         group by g.group_name, extract(dow from g.day), g.hour
        on conflict (lot_id, group_name, dow, hour) do update
           set median_occupancy = excluded.median_occupancy,
               samples = excluded.samples, computed_at = excluded.computed_at;
        get diagnostics n = row_count;
        delete from public.occupancy_profile p where p.lot_id = lot.id and p.computed_at < now();
        written := written + n;
    end loop;
    return written;
end $$;
revoke all on function public.refresh_occupancy_profile(boolean) from public, anon, authenticated;
```

(`delete ... computed_at < now()` removes cells not rewritten this run, e.g. a group that no longer exists; `now()` is the transaction start, so rows written in this run are kept.) `supabase/jobs.sh` gets `run refresh_occupancy_profile` (after the notification jobs); `supabase/notifications-cron.sh` the equivalent `psql` line. The 6-hour guard makes the 5-minute loop cheap.

### Algorithm, worked example

Lot 1, timezone `America/Bogota`, group `car`, capacity 40, defaults (K = 8, min samples 4, decay 0.85, full threshold 100 %). 

*Profile cell, Wednesday 17:00.* Occupancy at 17:00 on the last eight Wednesdays: 33, 35, 36, 38, 31, 35, 39, 60 (the 60 was a holiday event). Sorted: 31, 33, 35, 35, 36, 38, 39, 60 -> median = (35 + 35) / 2 = **35.00**, `samples = 8` (the mean would have been 38.4). The cells for the rest of the day come out the same way:

| Wed hour | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | Thu 00 | 01 | 02 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| profile | 24 | 27 | 31 | 35 | 38 | 36 | 30 | 22 | 15 | 10 | 7 | 6 | 5 |

*Forecast.* Now = Wednesday 14:20, live cars inside = 31, `horizon = 12`:

- `profile_now` = 24 + (20 / 60) x (27 - 24) = **25.00**; deviation `D = 31 - 25 = +6`.
- Mark 15:00: `a = 40/60 = 0.667` h; `0.85^0.667 = 0.897`; raw = 27 + 6 x 0.897 = **32.38**.
- 16:00: `a = 1.667`, factor 0.763, raw = 31 + 4.58 = 35.58. 17:00: `a = 2.667`, factor 0.648, raw = 35 + 3.89 = **38.89**. 18:00: `a = 3.667`, factor 0.551, raw = 38 + 3.31 = **41.31**. 19:00: factor 0.468, raw = 38.81. 20:00: 32.39. 21:00: 24.03. 22:00: 16.73. 23:00: 11.47. 00:00: 8.25. 01:00: 7.06. 02:00: 5.90.
- Displayed `expected` = round(min(raw, 40)): 15:00 **32**, 16:00 36, 17:00 39, 18:00 **40** (clamped), 19:00 39, 20:00 32, 21:00 24, 22:00 17, 23:00 11, 00:00 8, 01:00 7, 02:00 6.
- Full threshold = 40 x 100 % = 40. The live point (14:20, 31) and 15:00..17:00 are below it; 18:00 (41.31) is above. Crossing between 17:00 (38.89) and 18:00 (41.31): fraction `(40 - 38.89) / (41.31 - 38.89) = 0.459` -> 17:27.5 -> rounded to 15 minutes -> **`full_at = "17:30"`**.
- Levels (busy from 32 = 80 %): 15:00 busy (32.38), 16:00 busy, 17:00 busy, 18:00 **full**, 19:00 busy, 20:00 busy (32.39), 21:00 free, ... 
- `samples` = 8 on every cell used -> `confidence = high`.

*Minimum history.* A lot whose first session was 23 days ago has at most 3 Wednesdays in the grid: `samples = 3 < 4` -> the cell is unusable -> `status = insufficient_history`, no groups, nothing on screen.

### Staff RPC

```sql
occupancy_forecast(p_horizon_hours integer default 12) returns jsonb
```
`security definer`, `stable`, `set search_path = public`; `perform public.require_app_user();` then `lot := public.current_lot_id();` (any lot member; operators included); `p_horizon_hours` outside 1..24 -> `InvalidForecastHorizonError`; returns `public.forecast_compute(lot, p_horizon_hours, now())`. `grant execute ... to authenticated`, `revoke ... from public, anon`.

`forecast_compute(p_lot integer, p_horizon integer, p_now timestamptz) returns jsonb` (internal, revoked from API roles; tests call it as the owner with a fixed `p_now`). Sketch:

```sql
-- settings (defaults when the lot has no row): enabled, weeks, min_samples, w, full_pct
-- tz, now_local := p_now at time zone tz, hour0 := date_trunc('hour', now_local),
-- f := extract(minute from now_local) / 60.0
-- if not enabled -> {"status":"disabled", ...}
for grp, cap in select v.g, public.group_capacity(p_lot, v.g)
                  from (values ('car'), ('moto')) v(g) where public.group_capacity(p_lot, v.g) > 0 loop
    cur := (select count(*) from public.parking_sessions s
              join public.vehicles v2 on v2.id = s.vehicle_id
              join public.categories c on c.id = v2.category_id
             where s.lot_id = p_lot and s.status = 'open'
               and public.category_group(c.name) = grp);
    -- profile value + samples for hour0, hour0 + 1h and each hour0 + k h (k = 1..horizon):
    --   select median_occupancy, samples from occupancy_profile
    --    where lot_id = p_lot and group_name = grp
    --      and dow = extract(dow from mark) and hour = extract(hour from mark)
    -- any missing cell or samples < min_samples -> skip the group
    p_now_val := p(hour0) + f * (p(hour0 + 1h) - p(hour0));
    dev := cur - p_now_val;
    for k in 1 .. p_horizon loop
        mark := hour0 + k * interval '1 hour';
        a := extract(epoch from mark - now_local) / 3600.0;
        raw := p(mark) + dev * power(w, a);
        -- expected := round(least(greatest(raw, 0), cap)); level by raw vs cap * 0.8 and cap * full_pct / 100
        -- first crossing: previous point (a_prev, v_prev) starts at (0, cur)
        --   t := a_prev + (thr - v_prev) / (raw - v_prev) * (a - a_prev)  when v_prev < thr <= raw
    end loop;
    -- full_at := to_char(date_trunc('hour', x) + round(extract(minute from x) / 15) * interval '15 minutes', 'HH24:MI')
    --   where x := now_local + t * interval '1 hour'
end loop;
-- status: 'ok' when at least one group was forecast; 'no_capacity' when no group has capacity;
--         'insufficient_history' otherwise
```

Returned JSON (staff):

```json
{
  "lot_id": 1,
  "timezone": "America/Bogota",
  "generated_at": "2026-11-04T19:20:00Z",
  "status": "ok",
  "horizon_hours": 12,
  "profile_computed_at": "2026-11-04T16:05:00Z",
  "groups": [{
    "group": "car", "capacity": 40, "current": 31,
    "confidence": "high", "samples": 8,
    "full_now": false, "full_at": "17:30",
    "hours": [
      {"hour_start": "2026-11-04T15:00", "hour": 15, "expected": 32, "level": "busy"},
      {"hour_start": "2026-11-04T18:00", "hour": 18, "expected": 40, "level": "full"}
    ]
  }]
}
```

`status` is one of `ok`, `disabled`, `insufficient_history`, `no_capacity`; `hours` always has `horizon_hours` entries when the group is present; `hour_start` is a local (no offset) `YYYY-MM-DDTHH:00` string; `full_at` is `HH:mm` or `null`; `profile_computed_at` is the oldest `computed_at` used (null when no group).

### Public block

```sql
create or replace function public.public_forecast_block(p_lot_id integer)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare cfg_public boolean; staff jsonb;
begin
    select coalesce(fs.public_enabled, true) into cfg_public
      from public.parking_lots l left join public.forecast_settings fs on fs.lot_id = l.id
     where l.id = p_lot_id;
    if not coalesce(cfg_public, false) then
        return jsonb_build_object('status', 'hidden', 'groups', '[]'::jsonb);
    end if;
    staff := public.forecast_compute(p_lot_id, 12, now());
    return jsonb_build_object(
        'status', staff ->> 'status',
        'timezone', staff ->> 'timezone',
        'groups', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'group', g ->> 'group', 'confidence', g ->> 'confidence',
                       'full_now', (g ->> 'full_now')::boolean, 'full_at', g -> 'full_at',
                       'hours', (select jsonb_agg(jsonb_build_object(
                                     'hour', (h ->> 'hour')::integer, 'level', h ->> 'level')
                                  order by h ->> 'hour_start')
                                   from jsonb_array_elements(g -> 'hours') h)))
              from jsonb_array_elements(staff -> 'groups') g), '[]'::jsonb));
exception when others then
    return jsonb_build_object('status', 'unavailable', 'groups', '[]'::jsonb);
end $$;
revoke all on function public.public_forecast_block(integer) from public, anon, authenticated;
```

The wrapper:

```sql
alter function public.public_availability(integer) rename to public_availability_base;
revoke all on function public.public_availability_base(integer) from public, anon, authenticated;

create function public.public_availability(p_lot_id integer)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare base jsonb := public.public_availability_base(p_lot_id);
begin
    if base is null then return null; end if;
    return base || jsonb_build_object('forecast', public.public_forecast_block(p_lot_id));
end $$;
grant execute on function public.public_availability(integer) to anon, authenticated;
```

Public JSON added to the existing payload (`lot`, `max_reservation_hours`, `categories` untouched):

```json
"forecast": {
  "status": "ok",
  "timezone": "America/Bogota",
  "groups": [{"group": "car", "confidence": "high", "full_now": false, "full_at": "17:30",
              "hours": [{"hour": 15, "level": "busy"}, {"hour": 18, "level": "full"}]}]
}
```
Possible `status`: `ok`, `hidden` (lot disabled it or the forecast is off), `insufficient_history`, `no_capacity`, `disabled`, `unavailable`. The payload has no counts, capacities, samples, plates or sessions. Cost: three profile lookups per group plus one open-session count, well inside the anon 5 s timeout.

### Backtest RPC

```sql
occupancy_forecast_backtest(p_weeks integer default 4) returns jsonb
```
`require_lot_admin()` returns the lot; `p_weeks` outside 1..12 -> `InvalidReportRangeError`. Procedure (all in one statement over `occupancy_grid(lot, today - 7 * (p_weeks + K), today - 1)`, with `K`, `min_samples`, `w` from the lot's settings):

- For every evaluated day `d` in the last `p_weeks` weeks and every (group, hour), the **as-of prior** is the median of that cell on `d - 7, d - 14, ..., d - 7K`, restricted to days on or after the lot's first session and requiring `count >= min_samples` (the profile exactly as it would have been computed that morning, without the future).
- **Issue hours** 08:00, 12:00 and 16:00. For issue hour `i` and lead `j` (1..12, target hour `i + j <= 23`): `forecast = least(greatest(prior(i + j) + (actual(i) - prior(i)) * w^j, 0), capacity)`; `error = abs(forecast - actual(i + j))`; the prior-only error is `abs(prior(i + j) - actual(i + j))`. Groups: `car`, `moto` with `group_capacity > 0`.
- Output: `{weeks, history_weeks, decay_pct, issue_hours: [8, 12, 16], groups: [{group, points, mae, mae_prior_only, bias, by_lead: [{lead_hours, points, mae, mae_prior_only}]}]}` with `by_lead` for leads 1, 3 and 6; `mae`/`bias` rounded to 2 decimals (vehicles); `points = 0` and `mae = null` when there is not enough history.

Worked check (3 points, group car, `w = 0.85`, lead 3): prior(i) = 24, actual(i) = 28, prior(i+3) = 35 -> forecast = 35 + 4 x 0.614 = 37.46; actual(i+3) = 38 -> error 0.54; prior-only error 3.0. MAE over many such points is the reported figure. A `mae` lower than `mae_prior_only` says the live blend helps.

### Settings RPCs

`get_forecast_settings() returns jsonb` (inserts the default row when missing) and `set_forecast_settings(p_settings jsonb) returns jsonb`, both `require_lot_admin()`, `security definer`, `revoke ... from public, anon`, `grant ... to authenticated`. Keys: `enabled`, `history_weeks`, `min_samples`, `blend_decay_pct`, `full_threshold_pct`, `public_enabled`; missing keys keep their value; unknown keys, wrong JSON types, out-of-range values or `min_samples > history_weeks` -> `InvalidForecastSettingError` (range-checked in the function so the error is typed instead of `23514`). A change to `history_weeks`, `min_samples` or `enabled` makes the next job run recompute the profile: the function deletes the lot's `occupancy_profile` rows.

### Typed errors

`InvalidForecastHorizonError`, `InvalidForecastSettingError`, `InvalidReportRangeError` (existing; reused for the backtest range), plus the helpers' `AdminRequiredError`, `InvalidTokenError`, `LotRequiredError`.

### Performance

- Refresh: K = 8 -> 56 days x ~300 sessions = ~17 000 sessions, each expanded to ~3 hourly marks -> ~50 000 rows aggregated; about a second per lot, once every 6 hours. K = 26 -> ~55 000 sessions, ~170 000 rows, still a few seconds.
- Staff RPC and public block: at most 6 profile cells x 13 lookups on the primary key plus one open-session count -> milliseconds.
- Backtest: grid over `7 x (p_weeks + K)` days (12 weeks + K = 26 -> 266 days, ~80 000 sessions) plus joins on at most ~270 days x 3 issue hours x 12 leads x 2 groups ≈ 19 000 pairs -> a few seconds, inside the 15 s `authenticated` timeout (`0074`). The reports section calls it on demand, never on page load.
- No new index (the `entry_time` range scan uses `ix_sessions_lot_entry` of `0069`).

## Flutter

### File tree

```
lib/features/check_out/
├── domain/entities/occupancy_forecast.dart        NEW
├── domain/repositories/check_out_repository.dart  MODIFIED (+ occupancyForecast)
└── infrastructure/
    ├── check_out_remote_data_source.dart          MODIFIED
    └── check_out_repository_impl.dart             MODIFIED
lib/features/home/
├── application/dashboard_cubit.dart               MODIFIED (forecast in the parallel fetch)
└── presentation/widgets/dashboard_widgets.dart    MODIFIED (+ OccupancyForecastCard)
lib/features/home/presentation/home_page.dart      MODIFIED (place the card)
lib/features/reports/
├── domain/entities/forecast_backtest.dart         NEW
├── domain/repositories/report_repository.dart     MODIFIED (+ getForecastBacktest)
├── application/reports_cubit.dart                 MODIFIED (+ loadBacktest)
├── infrastructure/report_remote_data_source.dart  MODIFIED
├── infrastructure/report_repository_impl.dart     MODIFIED
└── presentation/
    ├── reports_page.dart                          MODIFIED
    └── widgets/forecast_accuracy_section.dart     NEW
lib/features/public_booking/
├── domain/entities/public_booking.dart            MODIFIED (+ PublicForecast)
└── presentation/public_booking_page.dart          MODIFIED (+ _ForecastCard)
```

No new route, no new DI registration (`CheckOutRepository`, `ReportRepository` and `PublicBookingRepository` already exist), no change to `DashboardSnapshot`. Another change is editing `public_booking` concurrently: re-read the two public files before editing.

### Domain (`occupancy_forecast.dart`)

```dart
enum ForecastStatus { ok, disabled, insufficientHistory, noCapacity, unavailable }
enum ForecastConfidence { low, medium, high }
enum ForecastLevel { free, busy, full }

class ForecastHour extends Equatable {
  final int hour;            // 0..23, business time
  final int expected;        // vehicles, already clamped to capacity
  final ForecastLevel level;
}

class ForecastGroup extends Equatable {
  final String group;        // 'car' | 'moto'
  final int capacity;
  final int current;
  final ForecastConfidence confidence;
  final int samples;
  final bool fullNow;
  final String? fullAt;      // 'HH:mm' or null
  final List<ForecastHour> hours;   // ordered by time
  int get peakExpected;      // max(expected), 0 when empty
}

class OccupancyForecast extends Equatable {
  final ForecastStatus status;
  final List<ForecastGroup> groups;
  final String timezone;
  final DateTime? generatedAt;
  static const unavailable = OccupancyForecast(status: ForecastStatus.unavailable);
  bool get hasForecast => status == ForecastStatus.ok && groups.isNotEmpty;
  ForecastGroup? groupOf(String name);
  ForecastGroup? get firstToFill;     // the group with the earliest fullAt (HH:mm compare), fullNow first
  factory OccupancyForecast.fromJson(Map<String, dynamic> json);   // tolerant; unknown status -> unavailable
}
```
Pure Dart + `equatable`. The same parsing rules as `HourlyTraffic.fromJson` (`(raw as num?)?.toInt() ?? 0`, unknown enum names fall back safely, list items that are not maps are skipped).

Port: `Future<OccupancyForecast> occupancyForecast({int horizon = 12});` in `CheckOutRepository`; the data source calls `_client.rpc('occupancy_forecast', params: {'p_horizon_hours': horizon})` inside `try { ... } catch (error) { throw mapSupabaseError(error); }`.

### Application — `DashboardCubit`

- `DashboardLoaded` gains `final OccupancyForecast forecast` (default `OccupancyForecast.unavailable`); it joins `props`; `copyWith` preserves it; `_fromCache` leaves it at the default.
- `_fetch` adds `_sessions.occupancyForecast().catchError((Object _) => OccupancyForecast.unavailable)` to the record `.wait` (7 futures; Dart supports up to 9). A failed forecast does **not** set `complete = false`: it is not part of the cache, so a good cached snapshot is still written.
- The forecast is never written to `DashboardCache`/`DashboardSnapshot` (`schemaVersion` stays 1). While `isStale` the card is not rendered.
- Sealed states are unchanged (`DashboardLoading`, `DashboardLoaded`, `DashboardFailure`); the card derives its four views from them.

### Presentation — `OccupancyForecastCard`

In `lib/features/home/presentation/widgets/dashboard_widgets.dart`, placed in `home_page.dart` right after `TrendCard` inside the `if (stale == null)` block. A `BlocBuilder<DashboardCubit, DashboardState>` with `buildWhen` on `forecast` and loading changes (same pattern as `TrendCard`). Reuses `_KpiIcon`, `_TrendQuiet`-style quiet message, `StatusChip`, `SkeletonPulse`/`SkeletonBox`, `Space`, `Radii`.

- **Loading** (`DashboardLoading`): skeleton with the card's geometry (title row + 12 bar placeholders). Test gotcha: never `pumpAndSettle` while it is shown.
- **Success** (`forecast.hasForecast`): title `homeForecastTitle`, subtitle `homeForecastHint`; a headline from `firstToFill` (`homeForecastFullAt(group, time)` or `homeForecastFullNow(group)`) or `homeForecastNotFull` when no group fills; a `ChoiceChip` per group when there are two (`Key('forecast-group-car')`, `Key('forecast-group-moto')`); 12 bars (`Key('forecast-bar-<hour>')`) scaled to the group's capacity with the "full" bar in `colorScheme.error`, busy in `StatusColors.warning`, free in `colorScheme.primary`, hour labels every third bar; each bar wrapped in `Semantics(label: homeForecastBarSemantics(hour, expected, capacity))`; a confidence `StatusChip` (`homeForecastConfidenceHigh|Medium|Low`, tones success / neutral / pending). Tokens only.
- **Empty** (`insufficientHistory`, `noCapacity`, `disabled`): quiet message with an icon (`homeForecastInsufficient` / `homeForecastNoCapacity` / `homeForecastDisabled`); no chart.
- **Error** (`unavailable`): quiet message `homeForecastUnavailable` (the rest of the home is unaffected; the card has no retry of its own: the dashboard's pull-to-refresh reloads it).
- Operators see the card (it is a staff summary). The card has no admin shortcut.

### Reports — backtest section

- Entity `lib/features/reports/domain/entities/forecast_backtest.dart`: `ForecastBacktest {weeks, historyWeeks, decayPct, groups}`, `BacktestGroup {group, points, mae, maePriorOnly, bias, byLead}`, `BacktestLead {leadHours, points, mae, maePriorOnly}`; `static const empty`; `bool get hasData => groups.any((g) => g.points > 0)`; tolerant `fromJson` (`mae` may be null -> `double?`).
- Port `ReportRepository.getForecastBacktest({int weeks = 4})` -> RPC `occupancy_forecast_backtest`, param `p_weeks`.
- `ReportsLoaded` gains `backtest` (`ForecastBacktest`, default `.empty`), `backtestLoading` (`bool`), `backtestFailed` (`bool`); `ReportsLoaded.copyWith` (added by `add-period-comparison-reports`; if absent, add it here preserving every field) takes them. `ReportsCubit.loadBacktest({int weeks = 4})` mirrors `loadComparison`: no-op unless `ReportsLoaded`, emits `backtestLoading: true`, then the result or `backtestFailed: true`; never emits `ReportsLoading`/`ReportsFailure`. It is **not** part of `loadReports` (the RPC is the heaviest read; the owner asks for it).
- `ForecastAccuracySection` (public widget, `lib/features/reports/presentation/widgets/forecast_accuracy_section.dart`): `SectionHeader(icon: Icons.insights_outlined, title: reportsForecastTitle, subtitle: reportsForecastSubtitle)`; four states: initial/empty (`EmptyState` with a `FilledButton` `reportsForecastRun` that calls `onRun`), loading (`SkeletonPulse` + `SkeletonBox`), success (per group a `MetricCard` with the MAE `reportsForecastMae(value)` and a caption `reportsForecastPriorOnly(value)`, plus a `StatusChip` `reportsForecastBetter(percent)` when `mae < maePriorOnly`, and a lead list for 1/3/6 h), error (`EmptyState` + retry). Placed after the hourly traffic section in `_ReportsBody`.

### Public booking page

`PublicBookingAvailability` gains `final PublicForecast forecast` (default `PublicForecast.hidden`), parsed from `json['forecast']`, included in `props`. New classes in the same file: `PublicForecast {status, groups}` (`isVisible => status == ForecastStatus.ok && groups.isNotEmpty`), `PublicForecastGroup {group, confidence, fullNow, fullAt, hours}`, `PublicForecastHour {hour, level}` (reuse `ForecastStatus`, `ForecastConfidence`, `ForecastLevel` from check_out entities via import). `_ForecastCard` in `public_booking_page.dart` between the categories and the form: title `publicForecastTitle`, one row per group (`publicForecastGroupCar` / `publicForecastGroupMoto`) with the sentence `publicForecastFullAt(time)` / `publicForecastFullNow` / `publicForecastNotFull`, then 12 cells with hour text and a level icon (never colour alone: `Icons.check_circle_outline`, `Icons.timelapse`, `Icons.block`), `Semantics` label per cell, and a footnote `publicForecastDisclaimer`. Hidden entirely unless `isVisible`. Colours from `StatusColors`/`ColorScheme`.

### l10n keys (ES / EN, add to both ARB files, then `flutter gen-l10n`; grep for existing keys first)

| key | ES | EN |
|---|---|---|
| `homeForecastTitle` | Pronóstico de ocupación | Occupancy forecast |
| `homeForecastHint` | Próximas 12 horas según el historial | Next 12 hours from past weeks |
| `homeForecastFullAt` (`{group}`, `{time}` String) | {group}: se llenaría cerca de las {time} | {group}: expected to fill around {time} |
| `homeForecastFullNow` (`{group}` String) | {group}: ya está lleno | {group}: already full |
| `homeForecastNotFull` | No se prevé que se llene en las próximas 12 horas | Not expected to fill in the next 12 hours |
| `homeForecastGroupCar` / `homeForecastGroupMoto` | Autos / Motos | Cars / Motorcycles |
| `homeForecastConfidenceHigh` / `Medium` / `Low` | Confianza alta / media / baja | High / Medium / Low confidence |
| `homeForecastBarSemantics` (`{hour}` int, `{expected}` int, `{capacity}` int) | {hour}:00, se esperan {expected} de {capacity} | {hour}:00, {expected} of {capacity} expected |
| `homeForecastInsufficient` | Aún reunimos historial para pronosticar | Still collecting history to forecast |
| `homeForecastNoCapacity` | Configura la capacidad para ver el pronóstico | Set the capacity to see the forecast |
| `homeForecastDisabled` | El pronóstico está desactivado | The forecast is turned off |
| `homeForecastUnavailable` | Pronóstico no disponible | Forecast unavailable |
| `reportsForecastTitle` | Precisión del pronóstico | Forecast accuracy |
| `reportsForecastSubtitle` | Error medio al repetir el pronóstico sobre las últimas semanas | Mean error when replaying the forecast over recent weeks |
| `reportsForecastRun` | Calcular precisión | Compute accuracy |
| `reportsForecastMae` (`{value}` String) | Error medio: {value} vehículos | Mean error: {value} vehicles |
| `reportsForecastPriorOnly` (`{value}` String) | Solo con el historial: {value} | History only: {value} |
| `reportsForecastBetter` (`{percent}` int) | {percent} % mejor con datos en vivo | {percent}% better with live data |
| `reportsForecastLead` (`{hours}` int, `{value}` String) | A {hours} h: {value} | At {hours} h: {value} |
| `reportsForecastEmpty` | Aún no hay historial suficiente | Not enough history yet |
| `reportsForecastUnavailable` | No se pudo calcular la precisión | The accuracy could not be computed |
| `publicForecastTitle` | ¿Cuándo se llena? | When does it fill up? |
| `publicForecastFullAt` (`{time}` String) | Suele llenarse cerca de las {time} | Usually fills up around {time} |
| `publicForecastFullNow` | Ahora está lleno | Full right now |
| `publicForecastNotFull` | No suele llenarse en las próximas horas | Usually not full in the coming hours |
| `publicForecastGroupCar` / `publicForecastGroupMoto` | Autos / Motos | Cars / Motorcycles |
| `publicForecastLevelFree` / `Busy` / `Full` | Con espacio / Concurrido / Lleno | Spaces free / Busy / Full |
| `publicForecastDisclaimer` | Estimación según días anteriores; puede variar. | Estimate based on previous days; it may vary. |

### Offline behaviour

The forecast is time-sensitive and is **not cached**: `DashboardSnapshot` is unchanged, a stale (offline) dashboard shows no forecast card, and `_fromCache` returns `OccupancyForecast.unavailable`. The backtest and the public strip are online-only.

## Security

| Caller | `occupancy_forecast` | profile table | backtest / settings RPCs | `public_availability.forecast` |
|---|---|---|---|---|
| `anon` | revoked | no grant | revoked | aggregates only (levels, `full_at`, confidence), if `public_enabled` |
| operator | allowed, active lot only | select of the active lot | `AdminRequiredError` | n/a |
| lot admin | allowed | select | allowed | n/a |
| foreign `x-lot-id` | `LotRequiredError` | RLS: 0 rows | `LotRequiredError` | n/a |

- The public block is built from the staff payload by an allow-list of fields: no `capacity`, `current`, `samples`, `profile_computed_at`, session or plate data.
- `occupancy_grid`, `forecast_compute`, `group_capacity`, `refresh_occupancy_profile`, `public_forecast_block` and `public_availability_base` are not executable by API roles.
- Any failure inside the public block yields `unavailable`; it cannot break booking or reveal an error message to anon.
- Lot isolation: every query filters `lot_id = p_lot`; the staff RPC derives `p_lot` from `current_lot_id()`, the public path from the lot id the booking page already addresses.

## Risks / Trade-offs

- [Median needs history] The minimum-history rule hides the forecast for new lots; the card says it is collecting history.
- [Holidays] Out of scope; a holiday today is wrong at first and corrected by the live blend.
- [Reservation holds are not subtracted] A lot can look "not full" while bays are held; documented in the public disclaimer.
- [Category renamed or recategorised vehicle] Attribution uses the vehicle's current category group.
- [Stuck-open sessions] Capped at 72 h in the grid; they still count in the **live** open count (they are real rows), which is what the anomaly rule `session_open_long` is for.
- [Wrapper around `public_availability`] Later changes must edit `public_availability_base`; recorded in `docs/agent-memory.md`.
- [Public forecast may be wrong] Confidence label and disclaimer; `public_enabled` switch.

## Migration Plan

1. Apply `<NEXT>_occupancy_forecast.sql` (additive; the rename keeps the existing function and its tests working).
2. Edit `supabase/jobs.sh` / `notifications-cron.sh`, `docker compose restart supabase-jobs`; run `select public.refresh_occupancy_profile(true);` once to avoid waiting for the first loop.
3. Ship the Flutter build. An old client ignores `forecast`; a new client against an old database shows the "unavailable" quiet card and no public strip.
4. Rollback: `drop function public.public_availability(integer); alter function public.public_availability_base(integer) rename to public_availability; grant execute on function public.public_availability(integer) to anon, authenticated;` then drop the new objects.

## Open Questions

1. Holidays: keep out of scope, or add an admin-maintained exception list (`forecast_exceptions`)?
2. Public visibility default: on (chosen, because there is no settings UI) or opt-in?
3. Full threshold 100 % of capacity, or something like 95 % so "full" reads as "no point driving over"?
4. Should reservation holds count toward the forecast occupancy for the public page?
5. Is a settings screen wanted for the six forecast settings?
