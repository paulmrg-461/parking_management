## 1. Backend domain

- [x] 1.1 Add `exit_time: datetime | None = None`, `amount_charged: int | None
  = None`, `ticket_number: str | None = None` to `ParkingSession`
  (`app/domain/parking_session.py`), all optional so existing `check_in_service.py`
  call sites keep working unchanged

## 2. Backend infrastructure

- [x] 2.1 Add nullable `exit_time`, `amount_charged`, `ticket_number` columns
  to `ParkingSessionModel` (`app/infrastructure/models.py`)
- [x] 2.2 New Alembic migration `0007_add_checkout_fields_to_parking_sessions.py`
  (`down_revision = "0006"`) adding/dropping those three columns
- [x] 2.3 Extend `SqlAlchemyParkingSessionRepository._to_entity` to map the
  three new columns; extend `update()` to persist `status`, `exit_time`,
  `amount_charged`, `ticket_number` (not just `status`)

## 3. Backend application

- [x] 3.1 Add `app/application/check_out_service.py`: module-level
  `SessionNotFoundError`, `SessionAlreadyClosedError`; `CheckOutService(sessions,
  vehicles, tariffs)` with `async def close_session(self, session_id: int,
  exit_time: datetime | None = None) -> ParkingSession` — fetch session
  (404 if missing), reject if already closed (409), resolve vehicle category,
  compute fare via `FareCalculator.calculate_fare_for_session` with
  `has_active_monthly_pass=False` (`# TODO(monthly-passes)`), stamp
  `status=closed` / `exit_time` / `amount_charged=round(amount)` /
  `ticket_number=f"TCK-{session_id:06d}"`, persist via `sessions.update`

## 4. Backend presentation

- [x] 4.1 Add `CheckOutRead` schema (`app/presentation/schemas.py`):
  `id, plate, entry_time, exit_time, status, amount_charged, ticket_number`
- [x] 4.2 Add `POST /check-outs/{session_id}` (`app/presentation/
  routes/check_outs.py`), `Depends(get_current_user)`, mapping
  `SessionNotFoundError` -> 404, `SessionAlreadyClosedError` -> 409,
  `MissingHourlyTariffError` -> 404, `InvalidBillingPeriodError` -> 422
- [x] 4.3 Mount the `check_outs` router in `app/main.py`

## 5. Tests (priority deliverable)

- [x] 5.1 `test_check_out_endpoints.py`: success (open session -> 200,
  `amount_charged` matches a manually-computed expectation using an injected
  fixed `exit_time`, `status=closed`, `ticket_number` set); failure (unknown
  `session_id` -> 404; already-closed session -> 409); security
  (unauthenticated -> 401)
- [x] 5.2 Extend `test_parking_session_repository.py` (or a new file):
  `update()` round-trips `exit_time`/`amount_charged`/`ticket_number`

## 6. Flutter (parallel implementation against the API contract above)

- [x] 6.1 Add `lib/features/check_out/domain/` (`OpenSession`,
  `CheckOutReceipt` entities, `CheckOutRepository` port)
- [x] 6.2 Add `CheckOutCubit` (`application/`) orchestrating load-open-sessions
  / check-out-and-refresh
- [x] 6.3 Add `DioCheckOutRemoteDataSource` + DTOs + `CheckOutRepositoryImpl`
  (remote-only, no local cache)
- [x] 6.4 Add `CheckOutPage` (open-sessions list joined with `VehiclesCubit`
  for plate resolution, search by plate, confirm dialog, receipt dialog using
  `CopFormatter`) + `/check-out` route + home-page entry point
- [x] 6.5 Register in DI (`injection.dart`)
- [x] 6.6 Write 3 tests (Success / Failure / Security) per layer
- [x] 6.7 Confirm `flutter analyze` (0 issues) and `flutter test` (all green)
  pass with both the backend and Flutter halves merged

## 7. Verification

- [x] 6.1 `cd backend && uv run pytest -q` all green (pre-existing + new)
- [x] 6.2 `openspec validate check-out --strict`
- [x] 6.3 `openspec archive check-out -y`
- [x] 6.4 Update `PROGRESS.md` (archived table, remaining list, test counts,
  migration range)
