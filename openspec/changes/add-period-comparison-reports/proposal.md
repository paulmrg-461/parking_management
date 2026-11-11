## Why

`docs/project-overview.md` §8 lists the gap: "the home shows the last 7 days and reports cover the selected range, but there is no month-over-month or year-over-year view". Today the only comparison on `/reports` is "this range vs the equally long range right before it" (`ReportsLoaded.previousTotal`, revenue only), so the owner cannot answer "is November better than October?" or "is this November better than last November?" without exporting two reports and subtracting by hand. A month that is still running makes the naive comparison worse: ten days of November against the whole of October always looks like a collapse.

## What Changes

- **New RPC `report_period_comparison(p_months, p_as_of)`** — admin-only, lot-scoped, business timezone. Returns one bucket per calendar month for the trailing `p_months` months (default 6, 1..24). Every bucket carries three windows with the same seven metrics: the month itself, the month before it, and the same month one year earlier. Metrics: revenue, entries, exits, average ticket, average stay (minutes), monthly-pass revenue, and reservations created / used.
- **Partial current month compared like with like.** When the newest bucket is still running, its two base windows are cut to the same number of elapsed days (1..D of the previous month and 1..D of the same month last year). The payload says so explicitly (`is_partial`, `days`, `full_month`).
- **No invented deltas.** A base window is flagged `covered = false` when the lot had no activity on or before its first day. The client shows a delta chip only when the base is covered, non-zero and of comparable length — the rule `TrendCard` already applies on the home (no chip on a zero or incomplete base).
- **Reports screen:** a "Comparación por periodo" section with a metric selector, a 6 / 12 month switch, a bar chart (month vs the same month last year), month-over-month and year-over-year chips, and a per-month list. The partial month is labelled "Mes en curso · D de N días".
- **Exports:** `reportCsv` and `buildRevenueReportPdf` gain the comparison (raw rows in the CSV; a chart plus a table in the PDF).
- **Resilience:** a failing comparison RPC degrades to an empty section with a retry, exactly like `HourlyTraffic`; it never fails the page.
- **Indexes:** two partial indexes so the monthly windows are range scans (see `design.md` §Performance); `0069_scale_hardening` only covers `(lot_id, entry_time)`.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `reports`: adds the monthly period comparison (RPC contract, partial-month rule, delta rule, screen section, exports, degradation and access control). Existing requirements are unchanged.

## Impact

- **Database:** one migration, `<NEXT>_report_period_comparison.sql` (use the next free number at implementation time; the head is `0103`, `add-public-booking-captcha`, already merged). It creates `ix_sessions_lot_exit_closed`, `ix_pass_payments_lot_paid`, `ix_reservations_lot_from` and the function `public.report_period_comparison(integer, date)`. No table or column changes. Tests appended to `supabase/tests/rpc_test.sql`.
- **Flutter (`lib/features/reports`)**: new entity `PeriodComparison` (+ `PeriodBucket`, `PeriodWindow`, `PeriodMetric`), `ReportRepository.getPeriodComparison`, `ReportRemoteDataSource.getPeriodComparison`, `ReportsLoaded.comparison` / `comparisonMonths` / `comparisonFailed` / `comparisonLoading`, `ReportsCubit.loadComparison`, widget `PeriodComparisonSection`, `reportCsv` and `buildRevenueReportPdf` parameters, ARB strings (ES/EN).
- **Docs:** `CHANGELOG.md`, `docs/project-overview.md` (§3 module map, §8), `docs/database.md` (§3 RPC catalog), `docs/agent-memory.md`.
- **Dependencies:** none added.
- **Breaking:** none. Every new parameter is optional and the existing "vs previous period" line stays.

## Non-Goals

- Consolidated (all sites) monthly comparison: the RPC is scoped to the active lot. `report_revenue_all` is untouched.
- Week-over-week or quarter views, custom comparison ranges, forecasts or targets.
- Materialised monthly aggregates: the figures are computed on demand (see the trade-off in `design.md`).
- Fixing `report_revenue.pass_revenue`, which today sums pass payments of every lot (see `design.md` §Findings). It is reported, not changed here.
- Offline access: reports stay remote-only, as today.
