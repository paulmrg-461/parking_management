## Why

`check-in` opens a `parking_sessions` row with `entry_time` and `status=open`.
`billing` computes the fare for a `[entry_time, exit_time)` interval but does
not persist anything. Nothing today closes a session, stamps its `exit_time`,
charges the fare, or issues a ticket number. `check-out` wires those two
already-shipped capabilities together into the operator-facing action that
ends a parking stay.

## What Changes

- Add `exit_time`, `amount_charged`, `ticket_number` columns to
  `parking_sessions` (nullable — only set once a session closes).
- Add `CheckOutService.close_session(session_id)` (`app/application/
  check_out_service.py`): loads the session, rejects unknown/already-closed
  sessions, resolves the vehicle's category, calls
  `FareCalculator.calculate_fare_for_session` for the elapsed
  `[entry_time, now)` period, stamps `status=closed`, `exit_time`,
  `amount_charged` (rounded to whole COP), and a generated `ticket_number`,
  then persists via the existing `ParkingSessionRepository.update`.
- Add `POST /check-outs/{session_id}` returning the closed session (with the
  vehicle's plate) for any authenticated user.

## Capabilities

### New Capabilities

- `check-out`: close an open parking session, charge its fare via `billing`,
  and issue an internal ticket number.

### Modified Capabilities

(none — `check-in` and `billing` are extended internally but their specs are
unchanged; `check-out` is additive)

## Impact

- Backend: `app/domain/parking_session.py` (three new optional fields),
  `app/infrastructure/models.py` (`ParkingSessionModel` new nullable columns),
  new Alembic migration `0007_add_checkout_fields_to_parking_sessions.py`,
  `SqlAlchemyParkingSessionRepository` (`_to_entity`/`update` extended),
  `app/application/check_out_service.py` (new), `app/presentation/
  routes/check_outs.py` (new) + mount in `main.py`, `CheckOutRead` schema.
- Non-goal: payment-method integration / electronic invoicing — receipts are
  internal-only per `AGENTS.md`. Non-goal: real monthly-pass lookup — the
  `has_active_monthly_pass` flag stays hardcoded `False` pending the
  `monthly-passes` capability.
- Flutter: none (backend-only; the parallel Flutter agent owns `lib/`/`test/`
  for this same capability).
