## Why

The home dashboard and the public booking page tell people how full the lot is **now**. Nobody can answer "will it be full at 6 pm?", which is the question that decides whether a customer drives over, whether the desk calls someone in, and whether the owner should hold bays for reservations. The history to answer it is already in `parking_sessions`: every entry and exit with timestamps, per lot, per vehicle category.

## What Changes

- **Deterministic forecast in SQL, no external ML service.** For each lot, vehicle group (`car`, `moto`, `heavy`, from `category_group()`), weekday and hour, the system computes the **median** occupancy over the last K same-weekday observations (default 8 weeks) and materialises it in a new table `occupancy_profile`, refreshed by the existing job runner.
- **Blend with live occupancy.** The next 12 hours are forecast as the profile plus today's deviation from the profile, decaying by a factor per hour ahead (default 0.85). The result is clamped to capacity, and the first time it reaches capacity gives an estimated "full at HH:mm" (or none), with a confidence label (`low`/`medium`/`high`) from the sample size.
- **Minimum-history rule.** Below a minimum number of same-weekday samples (default 4) the forecast is not shown (`status = insufficient_history`).
- **Two audiences.** (a) Staff see an "Pronóstico de ocupación" card on the home dashboard through the new `occupancy_forecast(p_horizon_hours)` RPC (any lot member). (b) Anonymous customers see a "¿Cuándo se llena?" strip on `/reserve` through a new `forecast` key in the existing `public_availability` payload, limited to aggregates: per group a `full_at` time, a confidence label and 12 hourly levels (`free`/`busy`/`full`). No counts, plates, sessions or timestamps of vehicles.
- **Backtest.** `occupancy_forecast_backtest(p_weeks)` (lot admin) replays the algorithm as of each past day and reports mean absolute error per group and lead time, next to the error of the profile alone, so the owner can see whether the live blend helps. The reports screen shows it in a "Precisión del pronóstico" section.
- **Per-lot settings** (`forecast_settings`: enabled, history weeks, minimum samples, decay, full threshold, public visibility) edited through `get_forecast_settings` / `set_forecast_settings` (RPC only in this change, like `set_public_booking_protection`).
- **Holidays are out of scope** (see `design.md`): the median absorbs isolated holidays and the live blend corrects the day itself.

## Capabilities

### New Capabilities

- `occupancy-forecast`: the algorithm, the profile table and its refresh, minimum history, the staff RPC, the backtest, settings, and the staff card and reports section.

### Modified Capabilities

- `capacity`: the public availability payload gains the aggregate-only `forecast` block, and the booking page renders it.

## Impact

- **Database:** one migration, `<NEXT>_occupancy_forecast.sql` (use the next free number at implementation time; it comes after `add-booking-waitlist` in the global order and after every earlier change that redefines `public_availability`). It creates `occupancy_profile`, `forecast_settings`, `occupancy_grid`, `group_capacity`, `forecast_compute`, `refresh_occupancy_profile`, the staff, backtest and settings RPCs, and **renames** `public_availability` to `public_availability_base` with a thin wrapper that adds the `forecast` key (no copy of the latest body is needed, so earlier or concurrent edits to it are not overwritten). Tests in `supabase/tests/rpc_test.sql`.
- **Ops:** `supabase/jobs.sh` and `supabase/notifications-cron.sh` call `refresh_occupancy_profile`; restart `supabase-jobs`.
- **Flutter:** `lib/features/check_out` (entity, port, data source, impl: `occupancyForecast()`), `lib/features/home` (`DashboardCubit`, `OccupancyForecastCard`), `lib/features/reports` (backtest entity, port, section), `lib/features/public_booking` (entity field and strip), l10n. No new route and no DI registration.
- **Docs:** `CHANGELOG.md`, `docs/project-overview.md`, `docs/database.md`, `docs/agent-memory.md`.
- **Breaking:** none. `public_availability` keeps its signature, grants and every existing key.
- **Order and merge protocol:** `openspec/IMPLEMENTATION-ORDER.md`; the wrapper approach is what keeps its `public_availability` edit safe in any wave-1 order.

## Non-Goals

- External or learned models, weather, events, seasonality beyond weekday and hour.
- A holiday calendar (an open question for the owner).
- Forecasting reservations or bay-level occupancy; reservation holds are not subtracted.
- Forecasting `heavy` (no capacity concept) or the total across groups.
- A settings screen for the forecast thresholds.
- Caching the forecast on the device: it is time-sensitive, so the offline dashboard cache does not store it.
