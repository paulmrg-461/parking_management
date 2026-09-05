## 1. Backend domain

- [x] 1.1 Add `app/domain/report.py`: `DailyRevenue`, `CategoryRevenue`,
  `RevenueReport` (`total`, `by_day`, `by_category`); `CategoryOccupancy`,
  `OccupancyReport` (`total_open`, `by_category`) dataclasses
- [x] 1.2 Add `ReportRepository(ABC)` to `app/domain/repositories.py`:
  `async def revenue_by_range(self, start_date: date, end_date: date) ->
  RevenueReport`, `async def current_occupancy(self) -> OccupancyReport`

## 2. Backend infrastructure

- [x] 2.1 Add `app/infrastructure/repositories/report_repository.py`:
  `SqlAlchemyReportRepository(session)` implementing both port methods with
  `select(...).group_by(...)`/`func.sum`/`func.count`/joins across
  `parking_sessions` -> `vehicles` -> `categories`

## 3. Backend application

- [x] 3.1 Add `app/application/report_service.py`: module-level
  `InvalidReportRangeError`; `ReportService(reports: ReportRepository)` with
  `get_revenue_report(start_date, end_date)` (validates `start_date <=
  end_date`, else raises) and `get_occupancy_report()` (thin delegation)

## 4. Backend presentation

- [x] 4.1 Add `RevenueReportRead`, `DailyRevenueRead`, `CategoryRevenueRead`,
  `OccupancyReportRead`, `CategoryOccupancyRead` schemas
  (`app/presentation/schemas.py`)
- [x] 4.2 Add `app/presentation/routes/reports.py`: `GET /reports/revenue`
  and `GET /reports/occupancy`, both `Depends(require_admin)`, mapping
  `InvalidReportRangeError` -> 422
- [x] 4.3 Add `get_report_repository` to `app/presentation/deps.py`
- [x] 4.4 Mount the `reports` router in `app/main.py`

## 5. Tests (priority deliverable)

- [x] 5.1 `test_report_endpoints.py`: success (revenue sums correctly by day
  and by category for a range that includes some sessions and excludes
  others — assert the excluded session's amount is NOT counted; occupancy
  counts only `status=open` sessions grouped by category); failure
  (`start_date > end_date` -> 422); security (operator role -> 403 on both
  endpoints)
- [x] 5.2 `test_report_repository.py`: direct assertions on
  `SqlAlchemyReportRepository` aggregation math using the `session_factory`
  fixture

## 6. Verification

- [x] 6.1 `cd backend && uv run pytest -q` all green (pre-existing + new)
- [x] 6.2 `openspec validate reports --strict`
- [x] 6.3 `openspec archive reports -y`
- [x] 6.4 Update `PROGRESS.md` (archived table, remaining list, test counts)
