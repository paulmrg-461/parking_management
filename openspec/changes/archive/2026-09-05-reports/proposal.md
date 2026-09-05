## Why

Operators and admins currently have no way to see how much revenue the lot has
made or how many vehicles are parked right now without querying the database
directly. `check-in`/`check-out` persist the raw data (`parking_sessions`) but
nothing aggregates it into a revenue or occupancy view.

## What Changes

- Add `GET /reports/revenue?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`: sums
  `amount_charged` for closed sessions whose `exit_time` falls within the
  (inclusive, end-of-day) range, grouped by calendar day and by vehicle
  category.
- Add `GET /reports/occupancy`: counts currently open sessions grouped by
  vehicle category.
- Both endpoints are admin-only (manager-facing financial/operational data),
  unlike day-to-day operator actions (check-in/check-out) which only require
  authentication.
- No new tables, no new domain entities — pure read-only aggregation over
  `parking_sessions`, `vehicles`, and `categories`.

## Capabilities

### New Capabilities

- `reports`: revenue report (by day, by category, for a date range) and
  occupancy report (open sessions by category), both admin-only.

### Modified Capabilities

(none)

## Impact

- Backend: `app/domain/report.py` (new dataclasses), `app/domain/
  repositories.py` (new `ReportRepository` port), `app/infrastructure/
  repositories/report_repository.py` (new `SqlAlchemyReportRepository`),
  `app/application/report_service.py` (new, thin pass-through +
  range validation), `app/presentation/schemas.py` (new report schemas),
  `app/presentation/routes/reports.py` (new), `app/presentation/deps.py`
  (new `get_report_repository`), mount in `main.py`.
- No migration — purely read-only queries over existing columns.
- Flutter: none (backend-only; the parallel Flutter agent owns the web-first
  reports screen in `lib/`/`test/` for this same capability).
