## Context

`parking_sessions` currently has no `exit_time`/charge/ticket columns —
`check-in` only ever writes `entry_time` + `status=open`. `billing` exposes
`FareCalculator.calculate_fare_for_session(category_id, entry_time, exit_time,
tariff_repository, has_active_monthly_pass=False) -> Decimal`, a thin async
wrapper around the pure ceil-to-hour/night-window/daily-cap algorithm, raising
`InvalidBillingPeriodError` / `MissingHourlyTariffError`. `check-out` is the
first capability that writes to more than the `status` column of an existing
session, so `SqlAlchemyParkingSessionRepository.update` (today: `model.status
= session.status.value` only) must be extended.

## Goals / Non-Goals

**Goals:**
- Close an open session: stamp `exit_time = now()`, compute and persist the
  fare via `FareCalculator`, generate and persist a ticket number, flip
  `status` to `closed`.
- Reject an unknown `session_id` (404) and an already-closed session (409).
- Reuse `billing`'s error types (`MissingHourlyTariffError` -> 404,
  `InvalidBillingPeriodError` -> 422) rather than re-deriving fare rules here.

**Non-Goals:**
- Payment-method capture, receipts-as-electronic-invoices — per `AGENTS.md`,
  "Receipt/ticket internal only (no electronic invoicing)". `ticket_number`
  is an internal reference string, not a fiscal document.
- Real monthly-pass lookup — `has_active_monthly_pass=False` stays hardcoded
  with a `# TODO(monthly-passes)` marker; the subscription concept doesn't
  exist yet.
- Any offline/queued check-out — matches `check-in`'s own precedent
  (remote-only for now; `offline-sync` is a later, separate change).

## Decisions

- **Money stays integer COP.** `FareCalculator` returns a `Decimal`;
  `amount_charged` is persisted as `round(amount)` cast to `int` — COP has no
  sub-unit, matching `Tariff.amount: int` and `AGENTS.md`'s currency rule.
- **`has_active_monthly_pass=False` is hardcoded**, not derived, with an
  explicit `# TODO(monthly-passes)` comment at the call site — building a
  subscription lookup now would be scope creep ahead of that capability
  existing at all.
- **Ticket number format: `TCK-{session_id:06d}`.** Deterministic, unique
  (session ids are unique), needs no extra table/sequence, and is stable
  across retries (idempotent to compute, though `close_session` itself is not
  re-enterable once `status=closed` — a second call 409s).
- **`close_session(session_id: int, exit_time: datetime | None = None)`** —
  the optional `exit_time` param (defaulting to `datetime.now(UTC)` inside the
  method) is a small, deliberate signature addition beyond the original brief
  so tests can inject a fixed clock instead of monkeypatching `datetime.now`,
  keeping fare-amount assertions exact and deterministic.
- **No admin gating.** Check-out is a day-to-day operator action, symmetric
  with check-in and vehicle lookup — `Depends(get_current_user)` only, no
  `require_admin`.
- **Repository `update()` now persists all four mutable fields** (`status`,
  `exit_time`, `amount_charged`, `ticket_number`), not just `status` — the
  minimal change that keeps the port's existing single `update` method
  (rather than adding a parallel `close`-specific persistence path).

## Risks / Trade-offs

- [Server-generated `exit_time`] -> `InvalidBillingPeriodError` (exit <=
  entry) should never trigger in production since `exit_time` is always
  `>= entry_time` by construction (session already existed when `now()` is
  taken). Kept as a defensive 422 mapping anyway for clock-skew / injected-
  `exit_time` edge cases (tests exercise this path directly).
- [No idempotency key] -> if two check-out requests race for the same open
  session, the loser's `sessions.get_by_id` may still see `status=open`
  before the winner's `update` commits; a real concurrent-request race is
  out of scope for this change (matches `check-in`'s own duplicate-session
  check, which has the same non-atomic read-then-write shape).

## Migration Plan

New Alembic revision `0007_add_checkout_fields_to_parking_sessions.py`,
`down_revision = "0006"`: `op.add_column` for `exit_time` (nullable
`DateTime(timezone=True)`), `amount_charged` (nullable `Integer`),
`ticket_number` (nullable `String(20)`). All three nullable — existing open
sessions have none of them until closed. `downgrade()` drops all three.

## Open Questions

- None — `monthly-passes` (next in the planned order) will revisit
  `has_active_monthly_pass` once subscriptions exist.
