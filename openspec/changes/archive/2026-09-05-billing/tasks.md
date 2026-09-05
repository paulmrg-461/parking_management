## 1. Backend domain

- [x] 1.1 Add `CategoryTariffs` aggregate (`category_id`, `hourly: Tariff`,
  `daily: Tariff | None`, `nightly: Tariff | None`) in
  `app/domain/category_tariffs.py`, with `__post_init__` type-consistency
  checks (defense in depth over the `tariffs` capability's own validation)

## 2. Backend application

- [x] 2.1 Add `InvalidBillingPeriodError` and `MissingHourlyTariffError`
  (module-level exceptions) in `app/application/billing_service.py`
- [x] 2.2 Add `FareCalculator.calculate_fare(tariffs, entry_time, exit_time,
  has_active_monthly_pass=False) -> Decimal` — pure, sync: monthly-pass
  short-circuit, calendar-day split, night-window split (with midnight
  wraparound), ceil-to-hour per calendar-day per rate type, per-day cap,
  sum across days, non-negative clamp
- [x] 2.3 Add `FareCalculator.calculate_fare_for_session(category_id,
  entry_time, exit_time, tariff_repository, has_active_monthly_pass=False)
  -> Decimal` async thin wrapper that loads the category's tariff rows and
  delegates to `calculate_fare`

## 3. Backend presentation (optional quote endpoint)

- [x] 3.1 Add `GET /billing/quote` (`category_id`, `entry_time`, `exit_time`
  query params, authenticated) in `app/presentation/routes/billing.py`
  returning `{"amount": "<decimal-string>"}`
- [x] 3.2 Mount the `billing` router in `app/main.py`
- [x] 3.3 Write 2-3 endpoint tests (`test_billing_endpoints.py`)

## 4. Tests (priority deliverable)

- [x] 4.1 Write an exhaustive table of `FareCalculator.calculate_fare` cases
  in `backend/tests/test_billing_service.py`: exact 1h; 1h05m ceils to 2h;
  fully-inside-night-window; day-into-night crossing; night window crossing
  midnight; multi-day stay capped per day; monthly pass -> 0 regardless of
  duration; `exit_time <= entry_time` raises `InvalidBillingPeriodError`;
  midnight-exact boundary edge cases; negative/zero-rate defense-in-depth
  assertion (amount always >= 0)

## 5. Verification

- [x] 5.1 `cd backend && uv run pytest -q` all green (pre-existing + new)
- [x] 5.2 `openspec validate billing --strict`
- [x] 5.3 `openspec archive billing -y`
- [x] 5.4 Update `PROGRESS.md` (archived table, remaining list, test counts)
