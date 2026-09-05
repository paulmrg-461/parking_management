## Context

`parking_sessions` already carries everything a revenue/occupancy report
needs: `status`, `exit_time`, `amount_charged` (set by `check-out`), and
`vehicle_id` (joins to `vehicles.category_id -> categories.name`). This
change adds no new tables or domain aggregates — it is a read-only
aggregation view over data that already exists.

## Goals / Non-Goals

**Goals:**
- Revenue report for a date range: total, by calendar day, by category.
- Occupancy report: count of currently open sessions, by category.
- Keep the same hexagonal shape as every other capability (domain port ->
  infra SQL implementation -> thin application service), even though this is
  an ad-hoc analytics query rather than a CRUD aggregate.

**Non-Goals:**
- Exports (CSV/PDF) — future, if requested.
- Real-time streaming / websockets — polling the two `GET` endpoints is
  sufficient for a manager dashboard.
- Scheduled/emailed reports — out of scope.
- Hourly or finer revenue granularity — calendar-day buckets are enough for
  a first version; finer granularity can be added later without breaking
  the response shape (it would be additive).

## Decisions

- **Admin-only gating (`Depends(require_admin)`) for both endpoints.**
  Deliberately different from `check-in`/`check-out`/`vehicles` list, which
  only require `Depends(get_current_user)`. Revenue and occupancy are
  financial/operational reporting data intended for managers, not something
  a day-to-day operator needs to see or should be able to query freely.
- **No new tables / no new migration.** Everything the reports need
  (`amount_charged`, `exit_time`, `status`, category via `vehicles`) already
  exists. Introducing a materialized/denormalized reporting table would be
  premature optimization for the current data volume.
- **New `ReportRepository` port instead of a raw-session application
  service.** Every other capability's application service takes a domain
  repository port, not a SQLAlchemy `AsyncSession`, keeping the hexagonal
  boundary (`application` must not import `sqlalchemy`). A `ReportRepository`
  with two purpose-built methods (`revenue_by_range`, `current_occupancy`)
  is a reasonable new *port* even though the underlying query is ad-hoc
  aggregation SQL rather than a get/list/create/update/delete CRUD shape —
  the alternative (letting `report_service.py` hold an `AsyncSession`
  directly) would be the first application-layer SQLAlchemy dependency in
  the codebase and was rejected to stay consistent.
- **`RevenueReport`/`OccupancyReport` as small dataclasses in
  `app/domain/report.py`**, mirroring how other domain concepts are plain
  dataclasses (`Tariff`, `Vehicle`, etc.), not ORM models.
- **Day granularity, `date` keys as `"YYYY-MM-DD"` strings in the response.**
  Matches the request's own `start_date`/`end_date` query params.
- **`end_date` is treated as end-of-day (inclusive).** A caller asking for
  `start_date=2026-01-01&end_date=2026-01-01` expects to see sessions closed
  anywhere during that whole day, not only sessions closed exactly at
  midnight — the repository filters `exit_time < end_date + 1 day` rather
  than `exit_time <= end_date`.
- **`start_date > end_date` -> 422** via a module-level
  `InvalidReportRangeError` raised by `ReportService`, mapped to
  `HTTPException(422)` in the route — same shape as other validation errors
  in this codebase (e.g. `vehicles.py`'s `ValueError` -> 422 mapping).
- **Money stays integer COP** (`func.sum` over `Integer` columns; `total`/
  `amount` are `int`, coalescing to `0` when there are no matching rows —
  `COALESCE(SUM(...), 0)` via `func.coalesce`).

## Risks / Trade-offs

- [No pagination on `by_day`/`by_category`] -> acceptable; a lot's category
  count is small (single digits) and a sane date range keeps `by_day` small
  too. Can add pagination later if needed without breaking the shape.
- [Categories with zero activity are omitted from `by_category`/`by_day`
  rather than returned as zero rows] -> simplest correct behavior for a
  `GROUP BY`; the Flutter side can treat "absent" as zero.

## Migration Plan

None — no schema changes.

## Open Questions

- None blocking.
