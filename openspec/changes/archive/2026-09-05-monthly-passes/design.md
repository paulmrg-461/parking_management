## Context

`billing`'s `FareCalculator.calculate_fare` / `calculate_fare_for_session`
already accept `has_active_monthly_pass: bool = False` and return `Decimal("0")`
immediately when it is `True`. `check-out`'s `CheckOutService.close_session`
already calls `calculate_fare_for_session` with that flag hardcoded to
`False`, marked `# TODO(monthly-passes)`. No subscription concept exists yet.
`tariffs` is the closest reference for an admin-mutated, publicly-readable
reference-data CRUD capability tied to a category/vehicle: plain service
class, patch-dataclass merge-then-validate `update`, `Depends(get_current_user)`
for `GET`, `Depends(require_admin)` for mutations.

## Goals / Non-Goals

**Goals:**
- Let an admin record that a vehicle has an active subscription for a date
  range, at a given price.
- Let `check-out` charge `0` for a vehicle whose subscription covers the
  session's exit date.
- Mirror `tariffs`' exact shape (service, patch, routes, gating) so the
  capability is predictable and low-risk to review.

**Non-Goals:**
- Pro-rated or partial-period pricing (e.g. mid-month start) — a pass either
  covers the exit date or it doesn't; no proration math.
- Payment processing for the pass subscription itself — `amount` is stored
  as a record of what the subscription costs, nothing charges or reconciles
  it. That is a future `Payments & Billing`-shaped concern, out of scope here.
- Auto-renewal — passes do not roll over; an admin creates the next period's
  row explicitly.
- Multiple simultaneous active passes per vehicle — the system assumes at
  most one is meaningful at a time (see Decisions).

## Decisions

- **Date range + `active` flag**, not a single "expires_at" — mirrors how a
  subscription is actually sold (a specific paid period), and lets an admin
  deactivate a pass early without deleting history.
- **Single active pass assumed per vehicle.** `get_active_for_vehicle`
  returns one `MonthlyPass | None` via `scalar_one_or_none()`. If a data
  hygiene issue lets two overlapping active passes exist for the same
  vehicle, the query would need `LIMIT 1`-like behavior; taking "any one" of
  them is an explicit, accepted out-of-scope data-hygiene concern (matches
  the task brief) — not handled defensively here.
- **Admin-only mutations, any-authenticated-user reads** — identical gating
  to `tariffs`/`vehicles`, since this is reference/subscription data managed
  by admins but relevant to operators doing check-out lookups.
- **`amount` is informational**, not enforced or charged anywhere in this
  change — it exists so the CRUD screen and reports can show what the
  customer paid for the subscription; check-out's charge is always `0` when
  a pass is active, regardless of `amount`.
- **Reuse `VehicleNotFoundError`.** `check_in_service.py` already defines
  `VehicleNotFoundError`; `monthly_pass_service.py` imports and reuses it
  (rather than defining a second, same-named-but-distinct exception class)
  so a caller catching `VehicleNotFoundError` for one "vehicle doesn't exist"
  condition catches it for both, avoiding confusing `except` mismatches
  across modules that would occur with duplicate identically-named classes.

## Check-out wiring (Modified Capability: `check-out`)

Before:
```python
# TODO(monthly-passes): look up an active pass for this vehicle once
# that capability exists.
amount = await FareCalculator().calculate_fare_for_session(
    vehicle.category_id, session.entry_time, resolved_exit_time,
    self._tariffs, has_active_monthly_pass=False,
)
```

After:
```python
active_pass = await self._monthly_passes.get_active_for_vehicle(
    vehicle.id, resolved_exit_time.date()
)
has_active_monthly_pass = active_pass is not None
amount = await FareCalculator().calculate_fare_for_session(
    vehicle.category_id, session.entry_time, resolved_exit_time,
    self._tariffs, has_active_monthly_pass=has_active_monthly_pass,
)
```

`CheckOutService.__init__` gains a fourth constructor argument,
`monthly_passes: MonthlyPassRepository`. This is a breaking change to the
constructor signature (positional callers must add the new argument); the
route (`check_outs.py`) and its DI wiring (`deps.py`) are updated in this
same change, and the one existing test that constructs `CheckOutService`
directly (`test_check_out_service_computes_exact_amount_for_injected_exit_time`
in `test_check_out_endpoints.py`) is updated to pass a `monthly_passes`
repository. The `check-out` capability's spec requirements are unchanged —
"compute the fare via the billing capability" already covers this; only the
fare computation's input becomes real.

## Migration Plan

New Alembic revision `0008_create_monthly_passes.py`, `down_revision =
"0007"`: `op.create_table("monthly_passes", ...)` with `id` (PK), `vehicle_id`
(FK -> `vehicles.id`, indexed), `start_date`/`end_date` (`Date`, not
nullable), `amount` (`Integer`, not nullable), `active` (`Boolean`, default
`true`), `created_at` (`DateTime(timezone=True)`, `server_default=now()`).
`downgrade()` drops the index then the table, mirroring `0004_create_vehicles.py`.

## Risks / Trade-offs

- [Single-active-pass assumption] -> if two active, overlapping passes
  exist for one vehicle (a data hygiene issue that should be prevented by
  admin UI validation, not enforced here), `get_active_for_vehicle` returns
  an arbitrary one; since check-out only cares whether the result is
  `None` or not, this has no observable effect on the charged amount.
- [`CheckOutService` constructor signature change] -> any other caller
  constructing it positionally would break; grepped and confirmed the only
  call sites are `check_outs.py` (updated) and the one direct test
  (updated).

## Open Questions

- None.
