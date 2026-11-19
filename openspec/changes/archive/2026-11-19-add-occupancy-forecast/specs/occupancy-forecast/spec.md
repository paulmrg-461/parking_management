## ADDED Requirements

### Requirement: Occupancy profile from session history
The system SHALL keep, per lot, vehicle group (`car`, `moto`, `heavy`), weekday and hour, the median net occupancy observed at that hour mark on the last K completed same-weekday dates (K = `history_weeks`, default 8), where the occupancy at a mark is the number of sessions with `entry_time <= mark < exit_time` (open sessions counted until now, any stay capped at 72 hours) in the lot's business timezone. The system SHALL store the result with its sample count in `occupancy_profile`, SHALL exclude dates before the lot's first session, SHALL never include today, and SHALL refresh it from the scheduled job at most every 6 hours per lot without depending on pg_cron.

#### Scenario: Median ignores an outlier
- **WHEN** the last eight Wednesdays had 33, 35, 36, 38, 31, 35, 39 and 60 vehicles at 17:00
- **THEN** the profile for Wednesday 17:00 is 35.00 with 8 samples

#### Scenario: Net occupancy from entries and exits
- **WHEN** a vehicle entered at 09:30 and left at 11:10 on a past day
- **THEN** it counts toward the occupancy at 10:00 and 11:00 and not at 09:00 or 12:00

#### Scenario: Stuck session is capped
- **WHEN** a session has been open for ten days
- **THEN** it contributes to the history of at most its first 72 hours

#### Scenario: Dates before the first session are not samples
- **WHEN** a lot's first session was 23 days ago
- **THEN** each weekday has at most 3 samples

#### Scenario: Refresh is throttled and idempotent
- **WHEN** the job runs twice within six hours
- **THEN** the second run rewrites nothing, and a forced run rewrites the same values for unchanged data

#### Scenario: Profile is lot-scoped
- **WHEN** lot 2 has history and lot 1 has none
- **THEN** `occupancy_profile` has rows for lot 2 only and an operator of lot 1 sees none

### Requirement: Minimum history
The system SHALL NOT forecast a group whose required profile cells have fewer than `min_samples` (default 4) observations. WHEN no group can be forecast, the forecast status SHALL be `insufficient_history` and the response SHALL contain no groups.

#### Scenario: New lot
- **WHEN** every needed cell has 3 samples and the minimum is 4
- **THEN** `status` is `insufficient_history` and `groups` is empty

#### Scenario: Enough history
- **WHEN** every needed cell has at least 4 samples
- **THEN** `status` is `ok` and the group is present

#### Scenario: Lot without capacity
- **WHEN** neither car nor moto capacity is configured
- **THEN** `status` is `no_capacity`

#### Scenario: Disabled lot
- **WHEN** a lot disabled the forecast
- **THEN** `status` is `disabled` and no groups are returned

### Requirement: Forecast blends the profile with live occupancy
The system SHALL forecast, for each group with capacity, the next `p_horizon_hours` full hours (1 to 24, default 12) as `profile(mark) + (live - profile_now) * w^a`, where `live` is the number of open sessions of the group, `profile_now` interpolates the profile between the current and the next hour, `w = blend_decay_pct / 100` (default 0.85) and `a` is the number of hours from now to the mark. The displayed expected value SHALL be rounded and clamped to the group's capacity. The system SHALL mark a group `full_now` when the live value is at or above `capacity * full_threshold_pct / 100`, and otherwise SHALL set `full_at` to the first crossing of that threshold, interpolated linearly and rounded to 15 minutes in the lot's timezone, or null when there is none. Each hour SHALL have a level: `full` at or above the threshold, `busy` at or above 80 % of capacity, else `free`. The confidence SHALL be `high` with at least 7 samples, `medium` with 5 or 6 and `low` otherwise, using the smallest sample count among the cells used.

#### Scenario: Worked example
- **WHEN** it is Wednesday 14:20, 31 cars are inside, capacity is 40 and the Wednesday profile is 24, 27, 31, 35, 38, 36, 30, 22, 15, 10, 7, 6, 5 from 14:00 to 02:00
- **THEN** the expected values from 15:00 are 32, 36, 39, 40, 39, 32, 24, 17, 11, 8, 7, 6, `full_at` is `17:30`, the 18:00 level is `full` and the confidence is `high`

#### Scenario: Never exceeds capacity
- **WHEN** the unclamped forecast for 18:00 is 41.31 and capacity is 40
- **THEN** the expected value for 18:00 is 40

#### Scenario: Not expected to fill
- **WHEN** every forecast value stays below the threshold
- **THEN** `full_at` is null and `full_now` is false

#### Scenario: Already full
- **WHEN** the live occupancy is 40 of 40
- **THEN** `full_now` is true and `full_at` is null

#### Scenario: Low confidence
- **WHEN** the smallest sample count used is 4
- **THEN** the confidence is `low`

#### Scenario: Invalid horizon
- **WHEN** the horizon is 0 or 25
- **THEN** the system raises `InvalidForecastHorizonError`

#### Scenario: Day crossing midnight
- **WHEN** the forecast runs on Wednesday 22:30 with a horizon of 6
- **THEN** the marks after midnight use the Thursday profile

### Requirement: Staff forecast access
The system SHALL expose `occupancy_forecast` to every authenticated member of the active lot, SHALL return only the active lot's data, and SHALL refuse anonymous callers.

#### Scenario: Operator reads the forecast
- **WHEN** an operator of lot 1 calls `occupancy_forecast()` with `x-lot-id: 1`
- **THEN** the forecast of lot 1 is returned

#### Scenario: Anonymous refused
- **WHEN** a client holding only the anon key calls `occupancy_forecast`
- **THEN** Postgres denies execution

#### Scenario: Foreign lot
- **WHEN** a user who is not a member of lot 3 sends `x-lot-id: 3`
- **THEN** the system raises `LotRequiredError`

#### Scenario: Profile table isolation
- **WHEN** an operator of lot 1 selects from `occupancy_profile`
- **THEN** only lot 1 rows are returned

### Requirement: Home dashboard forecast card
The home dashboard SHALL show a forecast card with the earliest expected "full at" time, a chart of the next 12 hours per group, and the confidence label. The card SHALL show a skeleton while loading, a message when history is insufficient, capacity is missing or the forecast is disabled, a quiet unavailable message when the request failed without failing the rest of the dashboard, and SHALL NOT be shown or cached while the dashboard is serving offline cached data.

#### Scenario: Success
- **WHEN** the forecast has a car group with `full_at` 17:30
- **THEN** the card states that cars are expected to fill around 17:30 and draws 12 bars

#### Scenario: Insufficient history
- **WHEN** the status is `insufficient_history`
- **THEN** the card shows "Aún reunimos historial para pronosticar" and no chart

#### Scenario: Failure degrades
- **WHEN** the forecast request fails and the other dashboard requests succeed
- **THEN** the dashboard stays loaded, the card shows "Pronóstico no disponible" and the cached KPI snapshot is still written

#### Scenario: Offline cache excludes it
- **WHEN** the dashboard falls back to its cached snapshot
- **THEN** no forecast card is rendered and the cached snapshot contains no forecast

#### Scenario: Operators see it
- **WHEN** an operator opens the home screen
- **THEN** the forecast card is visible

#### Scenario: Narrow screen
- **WHEN** the card renders at 400 px with 1.6 text scale
- **THEN** no overflow occurs

### Requirement: Backtest
The system SHALL let a lot admin call `occupancy_forecast_backtest(p_weeks)` (1 to 12, default 4) to replay the forecast as of each past day using only data before that day, from issue hours 08:00, 12:00 and 16:00 for every lead up to the end of the day, and SHALL report per group the number of points, the mean absolute error in vehicles of the blended forecast, the error of the profile alone, the bias, and the same figures for leads of 1, 3 and 6 hours. The reports screen SHALL offer it on demand with loading, empty, success and error states.

#### Scenario: Error figures
- **WHEN** the prior is 24 at the issue hour, the live value is 28, the prior three hours later is 35 and the actual value is 38 with decay 0.85
- **THEN** that point contributes an error of 0.54 to the blended mean and 3.0 to the profile-only mean

#### Scenario: Not enough history
- **WHEN** the lot has too little history for any prior
- **THEN** every group reports 0 points and a null error

#### Scenario: Range
- **WHEN** an admin calls the backtest with 0 or 13 weeks
- **THEN** the system raises `InvalidReportRangeError`

#### Scenario: Operator refused
- **WHEN** an operator calls the backtest
- **THEN** the system raises `AdminRequiredError`

#### Scenario: On demand
- **WHEN** the reports page loads
- **THEN** the backtest is not requested until the admin taps "Calcular precisión"

#### Scenario: Backtest failure keeps the report
- **WHEN** the backtest request fails
- **THEN** the report stays loaded and the section shows an error with retry

### Requirement: Forecast settings
The system SHALL store per-lot forecast settings (`enabled`, `history_weeks` 4 to 26, `min_samples` 3 to 26 and not above `history_weeks`, `blend_decay_pct` 50 to 99, `full_threshold_pct` 50 to 100, `public_enabled`) readable and changeable only by lot admins through `get_forecast_settings` and `set_forecast_settings`, with a missing key keeping its value, and SHALL audit changes.

#### Scenario: Partial update
- **WHEN** an admin sets `{"blend_decay_pct": 90}`
- **THEN** only that value changes

#### Scenario: Invalid values
- **WHEN** an admin sets `min_samples` above `history_weeks`, or an unknown key
- **THEN** the system raises `InvalidForecastSettingError` and nothing changes

#### Scenario: Operator refused
- **WHEN** an operator calls `set_forecast_settings`
- **THEN** the system raises `AdminRequiredError`

#### Scenario: Audited
- **WHEN** an admin changes a setting
- **THEN** an `audit_log` row for `forecast_settings` records the changed column and the admin

#### Scenario: Window change recomputes
- **WHEN** an admin changes `history_weeks`
- **THEN** the lot's stored profile is cleared so the next job run recomputes it
