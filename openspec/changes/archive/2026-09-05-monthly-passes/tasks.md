## 1. Backend domain

- [x] 1.1 Add `MonthlyPass` dataclass (`app/domain/monthly_pass.py`): `id,
  vehicle_id, start_date, end_date, amount, active=True`
- [x] 1.2 Add `validate_pass_dates(start_date, end_date) -> None` raising
  `ValueError` when `end_date <= start_date`
- [x] 1.3 Add `MonthlyPassRepository(ABC)` to `app/domain/repositories.py`:
  `get_by_id`, `list_all`, `list_by_vehicle`, `get_active_for_vehicle
  (vehicle_id, on_date) -> MonthlyPass | None`, `create`, `update`, `delete`

## 2. Backend infrastructure

- [x] 2.1 Add `MonthlyPassModel` (`app/infrastructure/models.py`): FK
  `vehicle_id -> vehicles.id` (indexed), `start_date`/`end_date` (`Date`),
  `amount` (`Integer`), `active` (`Boolean`, default `True`), `created_at`
- [x] 2.2 New Alembic migration `0008_create_monthly_passes.py`
  (`down_revision = "0007"`)
- [x] 2.3 Add `SqlAlchemyMonthlyPassRepository` (`app/infrastructure/
  repositories/monthly_pass_repository.py`): `_to_entity` mapper, `flush()`
  never `commit()`, `get_active_for_vehicle` queries `vehicle_id = :id AND
  active = true AND start_date <= :on_date AND end_date >= :on_date`

## 3. Backend application

- [x] 3.1 Add `app/application/monthly_pass_service.py`: module-level
  `MonthlyPassNotFoundError` (new); reuse `VehicleNotFoundError` from
  `check_in_service.py`; `MonthlyPassPatch` dataclass; `MonthlyPassService
  (passes, vehicles)` with `create` (validates vehicle exists + dates),
  `list_all`, `list_by_vehicle`, `update` (merge-then-validate-then-persist,
  mirrors `TariffService.update`), `delete`

## 4. Backend presentation

- [x] 4.1 Add `MonthlyPassRead`/`MonthlyPassCreate`/`MonthlyPassUpdate`
  schemas (`app/presentation/schemas.py`)
- [x] 4.2 Add `app/presentation/routes/monthly_passes.py`: `GET
  /monthly-passes` (optional `vehicle_id` filter, `Depends(get_current_user)`),
  `POST`/`PATCH`/`DELETE /monthly-passes/{id}` (`Depends(require_admin)`);
  map `MonthlyPassNotFoundError`/`VehicleNotFoundError` -> 404, `ValueError`
  -> 422
- [x] 4.3 Add `get_monthly_pass_repository` (`app/presentation/deps.py`)
- [x] 4.4 Mount the `monthly_passes` router in `app/main.py`

## 5. Wire into check-out

- [x] 5.1 `CheckOutService.__init__` gains `monthly_passes:
  MonthlyPassRepository`; `close_session` looks up
  `get_active_for_vehicle(vehicle.id, exit_time.date())` and passes the real
  `has_active_monthly_pass` to `FareCalculator`, removing the
  `# TODO(monthly-passes)` comment and hardcoded `False`
- [x] 5.2 Update `check_outs.py` route + `deps.py` wiring to inject
  `MonthlyPassRepository` into `CheckOutService(...)`
- [x] 5.3 Update `test_check_out_endpoints.py`'s direct `CheckOutService(...)`
  construction to pass a `monthly_passes` repository

## 6. Tests (priority deliverable)

- [x] 6.1 `test_monthly_pass_repository.py`: success (create+get,
  `get_active_for_vehicle` matches an in-range pass, returns `None` for
  out-of-range); failure (unknown id returns `None`)
- [x] 6.2 `test_monthly_pass_endpoints.py`: success (admin creates a pass for
  an existing vehicle); failure (unknown vehicle -> 404, invalid date range ->
  422); security (non-admin cannot create/update/delete -> 403)
- [x] 6.3 Extend `test_check_out_endpoints.py`: check out a vehicle with an
  active monthly pass -> `amount_charged == 0`

## 7. Verification

- [x] 7.1 `cd backend && uv run pytest -q` all green (pre-existing + new)
- [x] 7.2 `openspec validate monthly-passes --strict`
- [x] 7.3 `openspec archive monthly-passes -y`
- [x] 7.4 Update `PROGRESS.md` (archived table, remaining list, test counts,
  migration range)
