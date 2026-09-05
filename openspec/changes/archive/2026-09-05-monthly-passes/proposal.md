## Why

Some vehicles pay a recurring subscription instead of a per-stay fare (e.g. a
tenant's car parked every day). `billing`'s `FareCalculator` already accepts a
`has_active_monthly_pass` flag and short-circuits to a `0` charge, and
`check-out` already calls it — but today that flag is hardcoded `False`
(`# TODO(monthly-passes)`) because no subscription concept exists yet. This
change adds `monthly_passes` (admin-managed date-range subscriptions per
vehicle) and wires the real lookup into `check-out` so a vehicle with an
active pass is checked out for `0`.

## What Changes

- Add a `MonthlyPass` concept: `vehicle_id`, `start_date`, `end_date`,
  `amount` (COP, informational — what the subscription itself costs, not
  charged at check-out), and an `active` flag, tied to a vehicle.
- Add backend endpoints: `GET /monthly-passes` (authenticated, optional
  `vehicle_id` filter), `POST /monthly-passes`, `PATCH /monthly-passes/{id}`,
  `DELETE /monthly-passes/{id}` (admin only) — same shape as `tariffs`.
- Enforce validation: the referenced vehicle must exist; `end_date` must be
  strictly after `start_date`.
- Wire `CheckOutService.close_session` to look up an active pass
  (`start_date <= exit_date <= end_date`, `active=true`) for the session's
  vehicle and pass the real result as `has_active_monthly_pass`, removing the
  hardcoded `False`.

## Capabilities

### New Capabilities

- `monthly-passes`: create/list/update/delete date-range subscriptions per
  vehicle, admin-only mutations, readable by any authenticated user.

### Modified Capabilities

- `check-out`: `CheckOutService.close_session` now derives
  `has_active_monthly_pass` from a real `MonthlyPassRepository.
  get_active_for_vehicle` lookup instead of the hardcoded `False` placeholder.
  The check-out spec's requirements are unchanged (still "compute the fare via
  the `billing` capability") — this only makes an existing input to that
  computation real instead of stubbed. See `design.md` for the detailed
  before/after.

## Impact

- Backend: `app/domain/monthly_pass.py` (new), `app/domain/repositories.py`
  (new `MonthlyPassRepository` port), `app/infrastructure/models.py`
  (`MonthlyPassModel`), new Alembic migration
  `0008_create_monthly_passes.py`, `app/infrastructure/repositories/
  monthly_pass_repository.py` (new), `app/application/monthly_pass_service.py`
  (new), `app/presentation/routes/monthly_passes.py` (new) + mount in
  `main.py`, `MonthlyPassRead`/`Create`/`Update` schemas, `get_monthly_pass_
  repository` dependency.
- `app/application/check_out_service.py` gains a `monthly_passes:
  MonthlyPassRepository` constructor dependency; `check_outs.py` route and
  its dependency wiring updated accordingly.
- Non-goals: pro-rated/partial-period pricing, payment processing for the
  pass subscription itself, auto-renewal. See `design.md`.
- Flutter: none (backend-only; the parallel Flutter agent owns `lib/`/
  `test/` for this same capability).
