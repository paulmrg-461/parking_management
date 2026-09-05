## Why

`check-in` opens a `parking_sessions` row with an `entry_time`. The upcoming
`check-out` change will close that session with an `exit_time` and needs a
single, trustworthy source of truth for how much to charge — combining the
category's hourly/daily/nightly `tariffs` rows, the ceil-to-hour rule, the
night-window-replaces-day rule, and the per-day cap. Today none of that math
exists anywhere. Building it as its own change keeps the highest-bug-risk
logic in the whole app isolated, pure, and exhaustively unit-tested before
`check-out` (which persists the charged amount) and `reports` (which
aggregates revenue) depend on it.

## What Changes

- Add a pure `FareCalculator` (`app/application/billing_service.py`) that
  computes the charge for a `[entry_time, exit_time)` interval given a
  category's tariffs (hourly, optional daily, optional nightly).
- Implement: ceil-to-hour billing, night-window-replaces-day-rate (with
  midnight wraparound), per-calendar-day daily-rate cap, and a
  `has_active_monthly_pass` flag that short-circuits the charge to `0`.
- Add a small domain aggregate (`app/domain/category_tariffs.py`) bundling a
  category's hourly/daily/nightly `Tariff` rows, since the existing `Tariff`
  entity models one rate row at a time (one row per category per type), not
  a bundle of all four rates.
- Add a thin async wrapper that loads a category's tariffs via
  `TariffRepository` and delegates to the pure calculator — no new DB tables.
- Optionally expose `GET /billing/quote` for a live fare preview.

## Capabilities

### New Capabilities

- `billing`: compute the fare for a parking stay from a category's tariffs,
  applying ceil-to-hour, night-window override, daily cap, and monthly-pass
  short-circuit rules, for use by `check-out` and `reports`.

### Modified Capabilities

(none)

## Impact

- Backend: `app/domain/category_tariffs.py` (new aggregate), `InvalidBillingPeriodError`,
  `app/application/billing_service.py` (`FareCalculator`), optional
  `app/presentation/routes/billing.py` + mount in `main.py`.
- No new DB tables or migrations — pure computation over existing `Tariff` data.
- Does not persist a session's charged amount — that remains `check-out`'s
  responsibility once it exists.
- Flutter: none (backend-only; client calls the backend for any fare amount).
