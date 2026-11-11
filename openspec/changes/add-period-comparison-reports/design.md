## Context

Verified against the code on `feature/supabase` (schema head `0103`):

- Reports RPCs are `security definer`, `stable`, `set search_path = public`, read the lot from `public.current_lot_id()`, call `perform public.require_admin()` and resolve the timezone with `select coalesce(business_timezone, 'America/Bogota') ... from public.parking_settings where lot_id = lot`. The newest example is `report_hourly_traffic(date, date)` in `supabase/migrations/0082_report_hourly_traffic.sql`; `report_reservations(date, date)` (`0099`) follows the same shape. Both raise `InvalidReportRangeError`.
- Revenue is `sum(parking_sessions.amount_charged)` over `status = 'closed'` rows whose `exit_time` is in the window (`report_revenue`, latest body in `0024_lot_scope.sql`). Entries count `entry_time` in the window whatever the status (`dashboard_trend`, `0080`). Average ticket in the repo is integer division `sum(amount_charged) / count(*)` over closed sessions (`report_revenue_all.by_lot.avg_ticket`, `0039`). Pass revenue is `sum(monthly_pass_payments.amount)` where `status = 'paid'` and `paid_at` is in the window (`dashboard_today`, `0038`, lot-filtered). Reservations are counted by `reserved_from` (`report_reservations`, `0099`).
- Indexes on `parking_sessions` today: `ix_sessions_lot_entry (lot_id, entry_time desc)` (`0069`), `ix_sessions_status_exit (status, exit_time)` (`0001`), `ix_sessions_lot (lot_id, status)` (`0023`). **There is no `(lot_id, exit_time)` index** (`docs/agent-memory.md` says "the 0069 lot/entry and lot/exit indexes"; only lot/entry exists). `monthly_pass_payments` has `ix_pass_payments_lot (lot_id)` and `ix_pass_payments_status (status, due_date)`. `category_reservations` has `ix_reservations_lot (lot_id)` plus partial indexes on active rows.
- `0074_statement_timeouts.sql` sets `statement_timeout = 15000` ms for `authenticated`.
- Flutter: `ReportsCubit.loadReports` (`lib/features/reports/application/reports_cubit.dart`) runs every report in one `Future.wait`; `getHourlyTraffic` and `getReservationReport` are wrapped with `.then(onError: ...)` so they degrade to `HourlyTraffic.empty` / `ReservationReport.empty`. `ReportsState` is sealed: `ReportsInitial`, `ReportsLoading`, `ReportsLoaded`, `ReportsFailure`. `ReportsLoaded` has no `copyWith`.
- Home comparison rule (`TrendCard` in `lib/features/home/presentation/widgets/dashboard_widgets.dart`): `comparable = previous.length == current.length && current.isNotEmpty && previousTotal > 0`; delta = `((current - previous) * 100 / previous).round()`; chip `StatusChip` with `StatusTone.success` / `warning` / `neutral` and `Icons.trending_up` / `trending_down` / `trending_flat`; **no chip** when not comparable.
- Exports: `reportCsv` (`lib/features/reports/presentation/report_csv.dart`) emits `section,label,value` rows; `buildRevenueReportPdf` (`report_pdf.dart`) composes `PdfDocumentBuilder.section/row` and pure helpers (`revenueBarHeights`, `hourlyBarHeights`, `reportHourlyRows`). A function named `reportComparisonRows` already exists there for the previous-window lines — do not reuse that name. The PDF font (built-in Helvetica) has no em/en dash: PDF text must be ASCII/Latin-1.

### Findings (current code vs the feature idea)

1. `report_revenue.pass_revenue` and `pass_by_payment` (`0024`) are **not filtered by lot** (`from public.monthly_pass_payments p where p.status = 'paid' and p.paid_at ...`). The new RPC filters `p.lot_id = lot` (as `dashboard_today` does), so in a multi-lot install its `pass_revenue` can be lower than the figure on the summary card. This change does not alter `report_revenue`; the discrepancy is raised in Open Questions.
2. `parking_sessions.amount_charged` already excludes discounts (it is the net charged), so "revenue" here is net of discounts, matching `report_revenue.total`.
3. Reservations exist since `0021`; older months simply return `0`.

## Goals / Non-Goals

**Goals:**

- One request returns everything the screen and both exports need for N trailing months: the month, the month before, the same month last year.
- A month in progress is compared against the same number of elapsed days and is labelled as partial everywhere (screen, CSV, PDF).
- Deltas appear only on a base that is covered, non-zero and of comparable length.
- The reports page never fails because of this section.

**Non-Goals:** see `proposal.md`.

## Decisions

1. **One RPC, three windows per bucket.** Returning `current`, `previous_month` and `previous_year` inside every bucket (instead of two series the client must align) removes all date arithmetic from Dart. The cost is duplicated work for full months (bucket *i*'s `previous_month` equals bucket *i-1*'s `current`); see Performance. Rejected: two calls to `report_revenue` per month (2×N round trips, and `report_revenue` has no entries/stay/reservations).
2. **Calendar months in the business timezone**, never rolling 30-day windows: the owner thinks in months and the pass business is monthly.
3. **Partial month = same elapsed days.** With `D = extract(day from as_of)`, the base windows are days `1..least(D, days_in_base_month)` of the base month. Today is included (the label says "D de N días"); excluding today would hide the day the owner is looking at. When `D` exceeds the base month's length the base is the whole base month and is flagged `full_month = true` (comparable).
4. **`is_partial`** is true only for the newest bucket and only when `as_of` is before the last day of its month **or** `as_of` is the business today (a running day is not complete even on the 31st).
5. **`covered`** = the lot's first session (`min(entry_time)` in the business timezone) is on or before the window's first day. It is how the client knows a base is "incomplete" for a lot younger than the base window — the same idea as `TrendCard` refusing a short previous week.
6. **Delta rule lives in one pure Dart function** (`periodDelta`), mirroring `TrendCard`: `null` unless `base.covered && baseValue > 0 && (base.days == current.days || base.fullMonth)`. SQL returns facts; presentation decides chips.
7. **`p_as_of` parameter** (default: business today, never in the future). It makes the SQL tests deterministic without faking the clock and lets an admin reproduce a past export. It adds no overload: the function is new and has exactly one signature.
8. **Typed error:** reuse `InvalidReportRangeError` (already in `_domainCodes` of `lib/core/network/supabase_error_mapper.dart`) for `p_months` outside 1..24 and for a future `p_as_of`. Role errors come from the helpers: `AdminRequiredError`, `InvalidTokenError`, `LotRequiredError`.
9. **The section follows the active lot, also in consolidated mode.** When "Todas las sedes" is on, the section shows the caption "Solo la sede activa". Rejected: hiding it (the owner loses the view by toggling a filter that does not apply to it).
10. **The section is independent of the selected date range.** It always shows the trailing 6 or 12 months as of today; the range presets do not reload it with different parameters (they do reload it together with the rest, since `loadReports` refetches everything).

## Database

Migration file: `supabase/migrations/<NEXT>_report_period_comparison.sql` — **use the next free number at implementation time** (`0103` is taken by `add-public-booking-captcha`). One file, no table or column changes.

### Indexes

```sql
create index if not exists ix_sessions_lot_exit_closed
    on public.parking_sessions (lot_id, exit_time)
    where status = 'closed';

create index if not exists ix_pass_payments_lot_paid
    on public.monthly_pass_payments (lot_id, paid_at)
    where status = 'paid';

create index if not exists ix_reservations_lot_from
    on public.category_reservations (lot_id, reserved_from);

analyze public.parking_sessions;
analyze public.monthly_pass_payments;
analyze public.category_reservations;
```

Entries reuse `ix_sessions_lot_entry` from `0069_scale_hardening.sql`. `ix_sessions_lot_exit_closed` also speeds up `report_revenue`, `report_hourly_traffic` exits, `dashboard_today` and `dashboard_trend`, which today fall back to `ix_sessions_status_exit` + a lot filter.

### RPC

```sql
create or replace function public.report_period_comparison(
    p_months integer default 6,
    p_as_of date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.current_lot_id();
    tz text;
    today date;
    as_of date;
    elapsed integer;
    first_activity date;
    buckets jsonb;
begin
    perform public.require_admin();

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings
     where lot_id = lot;
    tz := coalesce(tz, 'America/Bogota');
    today := (now() at time zone tz)::date;
    as_of := coalesce(p_as_of, today);

    if p_months is null or p_months < 1 or p_months > 24 or as_of > today then
        raise exception 'InvalidReportRangeError';
    end if;
    elapsed := extract(day from as_of)::integer;

    select (min(s.entry_time) at time zone tz)::date into first_activity
      from public.parking_sessions s
     where s.lot_id = lot;

    with months as (
        select g as idx,
               (date_trunc('month', as_of::timestamp)
                    - make_interval(months => p_months - 1 - g))::date as m0
          from generate_series(0, p_months - 1) as g
    ),
    flagged as (
        select idx, m0,
               (m0 + interval '1 month')::date as m1,
               (idx = p_months - 1
                and (as_of < (m0 + interval '1 month')::date - 1 or as_of = today)
               ) as partial
          from months
    ),
    windows as (
        -- d0 inclusive, d1 exclusive, month_end = first day after the base month
        select idx, m0, partial, 'current'::text as kind,
               m0 as d0,
               case when partial then as_of + 1 else m1 end as d1,
               m1 as month_end
          from flagged
        union all
        select idx, m0, partial, 'previous_month',
               (m0 - interval '1 month')::date,
               case when partial
                    then least((m0 - interval '1 month')::date + elapsed, m0)
                    else m0 end,
               m0
          from flagged
        union all
        select idx, m0, partial, 'previous_year',
               (m0 - interval '1 year')::date,
               case when partial
                    then least((m0 - interval '1 year')::date + elapsed,
                               (m0 - interval '1 year' + interval '1 month')::date)
                    else (m0 - interval '1 year' + interval '1 month')::date end,
               (m0 - interval '1 year' + interval '1 month')::date
          from flagged
    ),
    measured as (
        select w.*, x.revenue, x.exits, x.stay_seconds,
               e.entries, p.pass_revenue, r.reservations, r.reservations_used
          from windows w
          cross join lateral (
              select coalesce(sum(s.amount_charged), 0) as revenue,
                     count(*) as exits,
                     coalesce(avg(extract(epoch from s.exit_time - s.entry_time)), 0)
                         as stay_seconds
                from public.parking_sessions s
               where s.lot_id = lot
                 and s.status = 'closed'
                 and s.exit_time >= w.d0::timestamp at time zone tz
                 and s.exit_time <  w.d1::timestamp at time zone tz
          ) x
          cross join lateral (
              select count(*) as entries
                from public.parking_sessions s
               where s.lot_id = lot
                 and s.entry_time >= w.d0::timestamp at time zone tz
                 and s.entry_time <  w.d1::timestamp at time zone tz
          ) e
          cross join lateral (
              select coalesce(sum(p.amount), 0) as pass_revenue
                from public.monthly_pass_payments p
               where p.lot_id = lot
                 and p.status = 'paid'
                 and p.paid_at >= w.d0::timestamp at time zone tz
                 and p.paid_at <  w.d1::timestamp at time zone tz
          ) p
          cross join lateral (
              select count(*) as reservations,
                     count(*) filter (where r.status = 'used') as reservations_used
                from public.category_reservations r
               where r.lot_id = lot
                 and r.reserved_from >= w.d0::timestamp at time zone tz
                 and r.reserved_from <  w.d1::timestamp at time zone tz
          ) r
    ),
    shaped as (
        select idx, m0, partial, kind,
               jsonb_build_object(
                   'start_date', to_char(d0, 'YYYY-MM-DD'),
                   'end_date', to_char(d1 - 1, 'YYYY-MM-DD'),
                   'days', d1 - d0,
                   'full_month', d1 = month_end,
                   'covered', first_activity is not null and first_activity <= d0,
                   'revenue', revenue,
                   'entries', entries,
                   'exits', exits,
                   'avg_ticket', case when exits = 0 then 0
                                      else (revenue / exits)::integer end,
                   'avg_stay_minutes', round(stay_seconds / 60.0)::integer,
                   'pass_revenue', pass_revenue,
                   'reservations', reservations,
                   'reservations_used', reservations_used
               ) as win
          from measured
    )
    select coalesce(jsonb_agg(bucket order by idx), '[]'::jsonb)
      into buckets
      from (
        select idx,
               jsonb_build_object(
                   'month', to_char(m0, 'YYYY-MM'),
                   'is_partial', bool_or(partial)
               ) || jsonb_object_agg(kind, win) as bucket
          from shaped
         group by idx, m0
      ) grouped;

    return jsonb_build_object(
        'lot_id', lot,
        'timezone', tz,
        'as_of', to_char(as_of, 'YYYY-MM-DD'),
        'months', p_months,
        'first_activity_date', case when first_activity is null then null
                                    else to_char(first_activity, 'YYYY-MM-DD') end,
        'buckets', buckets
    );
end;
$$;

revoke all on function public.report_period_comparison(integer, date) from public, anon;
grant execute on function public.report_period_comparison(integer, date) to authenticated;
```

The `revoke ... from public, anon` matters: Supabase default privileges hand new functions to `anon` (noted in `0103`). The role check inside is still what refuses operators.

### Returned JSON

```json
{
  "lot_id": 1,
  "timezone": "America/Bogota",
  "as_of": "2026-11-10",
  "months": 3,
  "first_activity_date": "2026-03-14",
  "buckets": [
    {
      "month": "2026-09",
      "is_partial": false,
      "current":        { "...window..." },
      "previous_month": { "...window..." },
      "previous_year":  { "...window..." }
    }
  ]
}
```

`buckets` is ordered oldest month first and always has exactly `months` elements. Every window has the same keys:

| key | type | meaning |
|---|---|---|
| `start_date` | string `YYYY-MM-DD` | first business day counted |
| `end_date` | string `YYYY-MM-DD` | last business day counted (inclusive) |
| `days` | integer | `end_date - start_date + 1` |
| `full_month` | boolean | the window is a whole calendar month |
| `covered` | boolean | the lot had a session on or before `start_date` |
| `revenue` | integer, minor units | `sum(amount_charged)`, closed sessions, `exit_time` in window |
| `entries` | integer | sessions with `entry_time` in window (any status) |
| `exits` | integer | closed sessions with `exit_time` in window |
| `avg_ticket` | integer, minor units | `revenue / exits` (integer division), `0` when `exits = 0` |
| `avg_stay_minutes` | integer | rounded mean of `exit_time - entry_time` of those exits, `0` when none |
| `pass_revenue` | integer, minor units | paid `monthly_pass_payments` of the lot, `paid_at` in window |
| `reservations` | integer | `category_reservations` with `reserved_from` in window |
| `reservations_used` | integer | of those, `status = 'used'` |

Errors (PostgREST `P0001`, message = name): `InvalidReportRangeError` (months outside 1..24, or `p_as_of` after the business today), `AdminRequiredError` (operator), `InvalidTokenError` (no profile), `LotRequiredError` (missing or foreign `x-lot-id`).

### Worked example

Lot 1, timezone `America/Bogota`, first session on 2026-03-14. Call `report_period_comparison(3, '2026-11-10')` on 2026-11-10.

| bucket | window | start..end | days | full_month | covered | revenue |
|---|---|---|---|---|---|---|
| 2026-09 | current | 2026-09-01..2026-09-30 | 30 | true | true | 11 800 000 |
| 2026-09 | previous_month | 2026-08-01..2026-08-31 | 31 | true | true | 11 000 000 |
| 2026-09 | previous_year | 2025-09-01..2025-09-30 | 30 | true | **false** | 0 |
| 2026-10 | current | 2026-10-01..2026-10-31 | 31 | true | true | 12 400 000 |
| 2026-10 | previous_month | 2026-09-01..2026-09-30 | 30 | true | true | 11 800 000 |
| 2026-10 | previous_year | 2025-10-01..2025-10-31 | 31 | true | **false** | 0 |
| 2026-11 (`is_partial`) | current | 2026-11-01..2026-11-10 | 10 | false | true | 4 200 000 |
| 2026-11 | previous_month | 2026-10-01..2026-10-10 | 10 | false | true | 3 500 000 |
| 2026-11 | previous_year | 2025-11-01..2025-11-10 | 10 | false | **false** | 0 |

Deltas the client derives (`periodDelta`):

- October vs September: `round((12 400 000 - 11 800 000) * 100 / 11 800 000) = round(5.08) = 5` → chip "+5 % vs mes anterior" (success).
- November (10 days) vs October (first 10 days): `round(700 000 * 100 / 3 500 000) = 20` → "+20 % vs mes anterior". Against the whole of October it would have been −66 %, which is the mistake the partial rule prevents.
- Every `previous_year` window: not covered → **no chip**, the row shows "Sin base de comparación".

Edge cases the tests must pin:

- `as_of = 2026-03-31`, called on 2026-03-31: `elapsed = 31`, bucket 2026-03 is partial (today is running); `previous_month` = `2026-02-01..2026-02-28` (`days = 28`, `full_month = true`, comparable); `previous_year` = `2025-03-01..2025-03-31`.
- `as_of = 2026-10-31` passed explicitly on 2026-11-10: bucket 2026-10 is **not** partial (a past, complete month).
- `as_of = 2028-02-29` (leap day, past date in the test): `previous_year` = `2027-02-01..2027-02-28`, `full_month = true`.

### Performance

- Windows per call: `3 × p_months` (18 by default, 72 at the maximum). Each window is four index range scans (`ix_sessions_lot_exit_closed`, `ix_sessions_lot_entry`, `ix_pass_payments_lot_paid`, `ix_reservations_lot_from`).
- Expected rows: a busy lot closes about 300 sessions a day ≈ 9 000 a month. Default call ≈ 18 × 9 000 = 162 000 session rows read twice (exit and entry scans) → well under one second. Maximum call (24 months) ≈ 650 000 rows → a few seconds worst case, inside the 15 s `statement_timeout` of `0074`.
- If the statement is cancelled (SQLSTATE `57014`), `mapSupabaseError` returns `ServerFailure` and the section degrades to its retry state.
- Rejected: a materialised `monthly_stats` table refreshed by `supabase/jobs.sh`. It would need invalidation for late offline check-outs (`StaleExitTimeError` allows exits up to 12 h old) and admin shift corrections, for a query that already runs in well under a second with the indexes above. Revisit if a lot exceeds roughly 2 000 exits a day.

## Flutter

### File tree

```
lib/features/reports/
├── domain/
│   ├── entities/period_comparison.dart                 NEW
│   └── repositories/report_repository.dart             MODIFIED (+ getPeriodComparison)
├── application/
│   └── reports_cubit.dart                              MODIFIED
├── infrastructure/
│   ├── report_remote_data_source.dart                  MODIFIED (+ getPeriodComparison)
│   └── report_repository_impl.dart                     MODIFIED
└── presentation/
    ├── report_csv.dart                                 MODIFIED (+ comparison)
    ├── report_pdf.dart                                 MODIFIED (+ comparison)
    ├── reports_page.dart                               MODIFIED (section + exports)
    └── widgets/period_comparison_section.dart          NEW
```

No new route and no new DI registration: `registerReportsModule` (`lib/app/di/modules/reports_module.dart`) already wires `ReportRemoteDataSource` → `ReportRepository` → `ReportsCubit`, and `/reports` is the deferred entry `lib/app/router/deferred/reports_entry.dart`.

### Domain — `period_comparison.dart`

All classes are `Equatable`, immutable, pure Dart. Parsing is tolerant like `HourlyTraffic.fromJson` (`(raw as num?)?.toInt() ?? 0`; a non-list `buckets` yields `PeriodComparison.empty`).

```dart
enum PeriodMetric { revenue, entries, exits, avgTicket, avgStay, passRevenue, reservations }

class PeriodWindow extends Equatable {
  const PeriodWindow({
    required this.startDate, required this.endDate,
    this.days = 0, this.fullMonth = false, this.covered = false,
    this.revenue = 0, this.entries = 0, this.exits = 0, this.avgTicket = 0,
    this.avgStayMinutes = 0, this.passRevenue = 0,
    this.reservations = 0, this.reservationsUsed = 0,
  });
  final DateTime startDate;   // local midnight, parsed from YYYY-MM-DD
  final DateTime endDate;     // inclusive
  final int days;
  final bool fullMonth;
  final bool covered;
  final int revenue;          // minor units
  final int entries;
  final int exits;
  final int avgTicket;        // minor units
  final int avgStayMinutes;
  final int passRevenue;      // minor units
  final int reservations;
  final int reservationsUsed;

  int valueOf(PeriodMetric metric);          // switch over the enum
  bool get hasMovement;                      // any metric != 0
  factory PeriodWindow.fromJson(Map<String, dynamic> json);
}

class PeriodBucket extends Equatable {
  const PeriodBucket({
    required this.month, required this.current,
    required this.previousMonth, required this.previousYear,
    this.isPartial = false,
  });
  final DateTime month;        // first day of the month
  final bool isPartial;
  final PeriodWindow current;
  final PeriodWindow previousMonth;
  final PeriodWindow previousYear;

  String get monthKey;         // 'YYYY-MM'
  int? deltaVsMonth(PeriodMetric metric) => periodDelta(current, previousMonth, metric);
  int? deltaVsYear(PeriodMetric metric)  => periodDelta(current, previousYear, metric);
  factory PeriodBucket.fromJson(Map<String, dynamic> json);
}

class PeriodComparison extends Equatable {
  const PeriodComparison({
    this.buckets = const [], this.months = 0, this.timezone = '',
    this.asOf, this.firstActivityDate,
  });
  static const empty = PeriodComparison();
  final List<PeriodBucket> buckets;   // oldest first (sorted by month in fromJson)
  final int months;
  final String timezone;
  final DateTime? asOf;
  final DateTime? firstActivityDate;

  bool get isEmpty => buckets.isEmpty;
  bool get hasData => buckets.any((b) => b.current.hasMovement);
  PeriodBucket? get latest => buckets.isEmpty ? null : buckets.last;
  int peakOf(PeriodMetric metric);    // max over current AND previousYear values (bar scale), 0 when quiet
  factory PeriodComparison.fromJson(Map<String, dynamic> json);
}

/// Percent change of [metric] between [current] and [base], or null when the
/// base cannot support a comparison (TrendCard rule: no chip on a zero or
/// incomplete base).
int? periodDelta(PeriodWindow current, PeriodWindow base, PeriodMetric metric) {
  final baseValue = base.valueOf(metric);
  final comparableLength = base.days == current.days || base.fullMonth;
  if (!base.covered || baseValue <= 0 || !comparableLength) {
    return null;
  }
  return ((current.valueOf(metric) - baseValue) * 100 / baseValue).round();
}
```

### Repository port

```dart
/// Trailing [months] calendar months of the active lot, each with the
/// previous month and the same month last year (`rpc/report_period_comparison`).
Future<PeriodComparison> getPeriodComparison({int months = 6});
```

Added to `ReportRepository`, `ReportRemoteDataSource`, `SupabaseReportRemoteDataSource` (`_client.rpc('report_period_comparison', params: {'p_months': months})`, wrapped in `try { ... } catch (error) { throw mapSupabaseError(error); }` like its siblings) and `ReportRepositoryImpl` (delegation). `p_as_of` is never sent by the app.

### Application — `ReportsCubit`

`ReportsState` keeps its four sealed classes (`ReportsInitial` → nothing requested, `ReportsLoading` → skeleton, `ReportsLoaded` → success, `ReportsFailure` → error + retry). `ReportsLoaded` gains:

| field | type | default | meaning |
|---|---|---|---|
| `comparison` | `PeriodComparison` | `PeriodComparison.empty` | monthly comparison (empty when the RPC failed) |
| `comparisonMonths` | `int` | `6` | months requested (6 or 12) |
| `comparisonFailed` | `bool` | `false` | the last comparison request failed (section shows retry) |
| `comparisonLoading` | `bool` | `false` | a months switch / retry is in flight (section shows its skeleton) |

All four join `props`. Add `ReportsLoaded copyWith({PeriodComparison? comparison, int? comparisonMonths, bool? comparisonFailed, bool? comparisonLoading})` that preserves every other field.

- `loadReports(...)` gains `int comparisonMonths = 6` and adds one more future to the existing `Future.wait`: `_repository.getPeriodComparison(months: comparisonMonths).then<PeriodComparison?>((r) => r, onError: (Object _) => null)`. `null` → `comparison: PeriodComparison.empty, comparisonFailed: true`.
- New `Future<void> loadComparison({required int months})`: no-op unless the state is `ReportsLoaded`; emits `copyWith(comparisonLoading: true, comparisonMonths: months)`, awaits the repository, then emits `copyWith(comparison: ..., comparisonFailed: false, comparisonLoading: false)`; on any error emits `copyWith(comparison: PeriodComparison.empty, comparisonFailed: true, comparisonLoading: false)`. It never emits `ReportsLoading` or `ReportsFailure` (the rest of the page must not flash). Re-read `state` after the await and drop the result if it is no longer `ReportsLoaded`.

`ReportsPage` keeps the chosen months in `_ReportsPageState` (`int _comparisonMonths = 6`) and passes it to `loadReports`, so a preset change does not reset the switch.

### Presentation — `PeriodComparisonSection`

`lib/features/reports/presentation/widgets/period_comparison_section.dart`, public `StatefulWidget` (it owns the selected `PeriodMetric`, default `PeriodMetric.revenue`):

```dart
const PeriodComparisonSection({
  super.key,
  required this.comparison,
  required this.months,
  required this.onMonthsChanged,   // ValueChanged<int>
  required this.onRetry,           // VoidCallback
  this.loading = false,
  this.failed = false,
  this.activeLotOnly = false,
});
```

Placed in `_ReportsBody` right after the hourly traffic block (before "Reservas"). Composition, design-system widgets only:

- `SectionHeader(icon: Icons.calendar_month_outlined, title: l10n.reportsPeriodTitle, subtitle: activeLotOnly ? l10n.reportsPeriodActiveLotOnly : l10n.reportsPeriodSubtitle)`.
- Controls in a `Wrap`: two `ChoiceChip`s for 6 / 12 months (`Key('period-months-6')`, `Key('period-months-12')`), and a `DropdownButtonFormField<PeriodMetric>` (`Key('period-metric')`) — seven options, and `docs/ui-kit.md` says more than five choices use a dropdown.
- The four states of the section:
  - **Loading** (`loading`): `SkeletonPulse` wrapping a row of `SkeletonBox` bars with the chart's height. (Test gotcha from `docs/agent-memory.md`: never `pumpAndSettle` while a `SkeletonPulse` is on screen — it repeats forever; use `pump()`.)
  - **Error** (`failed`): `EmptyState(icon: Icons.cloud_off_outlined, message: l10n.reportsPeriodUnavailable, action: TextButton(key: Key('period-retry'), onPressed: onRetry, child: Text(l10n.actionRetry)))`. It is deliberately not the full-page `ErrorState`: the page itself succeeded.
  - **Empty** (`!comparison.hasData`): `EmptyState(icon: Icons.calendar_month_outlined, title: l10n.reportsPeriodEmptyTitle, message: l10n.reportsPeriodEmpty)`.
  - **Success**: chart + latest-month summary + per-month list (below).
- **Chart** (`Key('period-chart')`): one group per bucket, two bars scaled to `comparison.peakOf(metric)`: the month in `colorScheme.primary` (the partial month in `colorScheme.tertiary`, like today's bar in `TrendCard`) and the same month last year in `colorScheme.outlineVariant`; a 2 dp baseline when a value is `0`; month label below (`DateFormat.MMM(l10n.localeName)`, plus the two-digit year on January). Each group is wrapped in `Semantics(label: l10n.reportsPeriodBarSemantics(month, value, previous))` and `Key('period-bar-<YYYY-MM>')`. With 12 months the chart scrolls horizontally inside a `SingleChildScrollView` so bars keep a minimum 24 dp width at 400 px. A two-entry legend (`reportsPeriodLegendCurrent`, `reportsPeriodLegendLastYear`).
- **Latest-month summary**: `MetricCard(label: <metric label>, value: <formatted>, caption: ...)`. When `latest.isPartial`: caption `l10n.reportsPeriodPartial(current.days, daysInMonth)`, a `StatusChip(label: l10n.reportsPeriodPartialChip, tone: StatusTone.pending)` with `Key('period-partial-chip')`, and the hint `l10n.reportsPeriodPartialHint(current.days)`. Below it a `Wrap` with the two delta chips.
- **Delta chips** (`_PeriodDeltaChip`, private): `delta == null` → plain `Text(l10n.reportsPeriodNoBase)` in `onSurfaceVariant` (no chip); otherwise `StatusChip` with label `reportsPeriodVsMonth` / `reportsPeriodVsYear` (`'+5 %'`, `'-12 %'`), or `reportsPeriodFlatMonth` / `reportsPeriodFlatYear` when `0`; tone `success` for `> 0`, `warning` for `< 0`, `neutral` for `0`; icons `Icons.trending_up` / `trending_down` / `trending_flat`. **Exception:** for `PeriodMetric.avgStay` the tone is always `StatusTone.neutral` (a longer stay is neither good nor bad).
- **Per-month list**: newest first, one row per bucket (`Key('period-row-<YYYY-MM>')`): month name + year, formatted value, and the two delta chips in a `Wrap` (so 400 px never overflows; the same fix `_DeltaRow` needed).
- **Formatting:** money metrics (`revenue`, `avgTicket`, `passRevenue`) through `Formatters.money` (which delegates to `Money`); `avgStay` through `Formatters.duration(l10n, Duration(minutes: value))`; counts as plain integers; `reservations` shows `reservations` with the caption `l10n.reportsPeriodReservationsUsed(reservationsUsed)`.
- Tokens only (`Space`, `Radii`, `Theme.of(context)`, `StatusColors`); every tappable control ≥ `Layout.minTouch`.

### Exports

- `reportCsv({..., PeriodComparison? comparison})`: when non-null and not empty, append
  - `['period', 'as_of', 'YYYY-MM-DD']`, and for a partial latest bucket `['period', 'partial_month', 'YYYY-MM']` and `['period', 'partial_days', D]`;
  - for every bucket and every metric name in `revenue, entries, exits, avg_ticket, avg_stay_minutes, pass_revenue, reservations, reservations_used`: `['period_<metric>', 'YYYY-MM', current]`, `['period_<metric>_prev_month', 'YYYY-MM', previousMonth]`, `['period_<metric>_prev_year', 'YYYY-MM', previousYear]`. Raw integers, no currency symbols, no deltas (a spreadsheet computes them); base rows are written even when not covered (the value is `0`).
- `buildRevenueReportPdf({..., PeriodComparison? comparison})`: when it has data, add `PdfDocumentBuilder.section(l10n.reportsPeriodTitle, [...])` after the hourly section, with `buildPeriodBarChart(comparison)` (revenue only, bars from the pure `periodBarHeights(List<int> values, {double height = 68})` — tallest = `height`, zero = `0`) and one row per bucket from the pure `reportPeriodRows({required AppLocalizations l10n, required PeriodComparison comparison})` → `List<({String label, String value})>`: label `'<MMM yyyy>'` or, for the partial bucket, `l10n.reportsPeriodPdfPartial(month, days)` (`'nov 2026 (1-10)'`); value `'<money> · <+5 % | n/d> · <+20 % | n/d>'` using `l10n.reportsPeriodPdfNoBase` for a null delta. **ASCII/Latin-1 only**: no em/en dash; the middle dot is allowed.
- `_ReportsPageState._export` and `_copyCsv` pass `state.comparison`.

### l10n keys (add to `lib/l10n/app_es.arb` and `lib/l10n/app_en.arb`, then `flutter gen-l10n`)

Check that none of these keys already exists before adding (a duplicate key silently wins in gen-l10n).

| key | ES | EN |
|---|---|---|
| `reportsPeriodTitle` | Comparación por periodo | Period comparison |
| `reportsPeriodSubtitle` | Cada mes frente al mes anterior y al mismo mes del año pasado | Each month against the previous month and the same month last year |
| `reportsPeriodActiveLotOnly` | Solo la sede activa | Active site only |
| `reportsPeriodMonths` (`{count}` int) | {count} meses | {count} months |
| `reportsPeriodMetricLabel` | Indicador | Metric |
| `reportsPeriodMetricRevenue` | Ingresos | Revenue |
| `reportsPeriodMetricEntries` | Entradas | Entries |
| `reportsPeriodMetricExits` | Salidas | Exits |
| `reportsPeriodMetricAvgTicket` | Ticket promedio | Average ticket |
| `reportsPeriodMetricAvgStay` | Estadía promedio | Average stay |
| `reportsPeriodMetricPassRevenue` | Ingresos por mensualidades | Monthly pass revenue |
| `reportsPeriodMetricReservations` | Reservas | Reservations |
| `reportsPeriodReservationsUsed` (`{count}` int) | {count} usadas | {count} used |
| `reportsPeriodPartial` (`{days}` int, `{total}` int) | Mes en curso · {days} de {total} días | Month in progress · {days} of {total} days |
| `reportsPeriodPartialChip` | Parcial | Partial |
| `reportsPeriodPartialHint` (`{days}` int) | Se compara con los primeros {days} días de cada mes | Compared with the first {days} days of each month |
| `reportsPeriodVsMonth` (`{delta}` String) | {delta} vs mes anterior | {delta} vs previous month |
| `reportsPeriodVsYear` (`{delta}` String) | {delta} vs año anterior | {delta} vs last year |
| `reportsPeriodFlatMonth` | Igual que el mes anterior | Same as the previous month |
| `reportsPeriodFlatYear` | Igual que el año anterior | Same as last year |
| `reportsPeriodNoBase` | Sin base de comparación | No comparison base |
| `reportsPeriodLegendCurrent` | Mes | Month |
| `reportsPeriodLegendLastYear` | Mismo mes del año anterior | Same month last year |
| `reportsPeriodEmptyTitle` | Aún no hay historial | No history yet |
| `reportsPeriodEmpty` | Cuando el parqueadero tenga movimiento verás aquí la comparación mensual. | Once the site has activity the monthly comparison will appear here. |
| `reportsPeriodUnavailable` | No se pudo cargar la comparación. | The comparison could not be loaded. |
| `reportsPeriodBarSemantics` (`{month}`, `{value}`, `{previous}` String) | {month}: {value}; año anterior: {previous} | {month}: {value}; last year: {previous} |
| `reportsPeriodPdfPartial` (`{month}` String, `{days}` int) | {month} (1-{days}) | {month} (1-{days}) |
| `reportsPeriodPdfNoBase` | n/d | n/a |

`actionRetry` already exists and is reused. `InvalidReportRangeError` has no entry in `FailureMessages._byCode` today; the app never triggers it for this RPC (it sends 6 or 12), so no mapping is added.

### Offline behaviour

Reports are remote-only (`ReportRepositoryImpl` has no local source). Offline, `loadReports` fails as it does today (`ReportsFailure` with retry). Nothing is cached; the home `DashboardSnapshot` is not touched.

## Security

| Caller | `report_period_comparison` |
|---|---|
| `anon` | Not executable (`revoke ... from public, anon`); even if granted, `current_lot_id()` raises `InvalidTokenError`. |
| operator (`users.role = 'operator'`) | `AdminRequiredError` from `require_admin()`. The `/reports` route is not in `operatorRoutes`. |
| admin (`users.role = 'admin'`), member of the active lot | Allowed; figures of the active lot only. |
| admin, `x-lot-id` of a lot they are not a member of | `LotRequiredError` from `current_lot_id()`. |

- Lot isolation: every subquery filters `lot_id = lot`, where `lot` is the validated `current_lot_id()`. The client never sends a lot id.
- `security definer` with `set search_path = public`; no dynamic SQL; the only inputs are an integer and a date.
- The payload is aggregates only (no plates, operators or customers).

## Risks / Trade-offs

- [Duplicate work for full months] → Accepted for a simpler contract; bounded by 72 windows and the indexes.
- [A lot's first month is flagged `covered = false` as a base even if it opened on the 2nd] → Intended: a base that misses days would inflate the delta. The value is still shown; only the chip is withheld.
- [`pass_revenue` differs from the summary card in multi-lot installs] → Documented under Findings; the new figure is the lot-correct one.
- [Average ticket uses integer division] → Same as `report_revenue_all`; at most one minor unit of rounding.
- [Late offline exits change a past month slightly] → Computed on demand, so the next load is correct; exports are snapshots.

## Migration Plan

1. Apply `<NEXT>_report_period_comparison.sql` (`docker compose up -d supabase-migrate`). Index creation takes a short lock on three tables; on a large production table run it in a quiet hour (the migration runs in a transaction, so `create index concurrently` is not available).
2. Wait for PostgREST to reload its schema cache (or restart it) before calling the new RPC, else `PGRST202`.
3. Ship the Flutter build. An old client ignores the new RPC; a new client against an old database gets a failed comparison and shows the retry state.
4. Rollback: `drop function public.report_period_comparison(integer, date);` and optionally the three indexes. No data to restore.

## Open Questions

1. Should `report_revenue.pass_revenue` / `pass_by_payment` be fixed to filter by lot (Finding 1)? It changes a number the owner already sees.
2. Is "today included in the partial month" the right reading, or should the partial window stop at yesterday?
3. Default months: 6 (chosen) or 12?
4. Is a consolidated (all sites) monthly comparison wanted later?
