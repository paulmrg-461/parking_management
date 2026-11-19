# reports Specification

## Purpose
TBD - created by archiving change reports. Update Purpose after archive.
## Requirements
### Requirement: Revenue report
An admin SHALL be able to request a revenue report for a date range, returning
the total charged amount, a breakdown by calendar day, a breakdown by vehicle
category and a breakdown by payment method, computed from closed sessions
whose exit time falls within the range (inclusive, end date treated as
end-of-day). The payment breakdown SHALL separate the money collected at the
desk (`cash`, `card`, `transfer`, `monthly_pass`, `exempt`) from the amount
paid through the online gateway, and the total SHALL keep counting each session
once, at `amount_charged`.

#### Scenario: Fetch revenue for a range
- **WHEN** an admin requests `GET /reports/revenue` with a `start_date` and
  `end_date`
- **THEN** the system returns the total revenue, an amount per calendar day,
  an amount per category and an amount per payment method, counting only
  closed sessions whose exit time falls within `[start_date, end_date]`

#### Scenario: Sessions outside the range are excluded
- **WHEN** a closed session's exit time falls before `start_date` or after
  `end_date`
- **THEN** its `amount_charged` is not included in the report total, day
  breakdown, or category breakdown

#### Scenario: A session paid partly online
- **WHEN** a 9000 session paid 6000 online and 3000 in cash is in the range
- **THEN** the total grows by 9000, the payment breakdown shows 3000 for the
  desk method used and 6000 for `online`, and no method is counted twice

### Requirement: Occupancy report
An admin SHALL be able to request an occupancy report, returning the count of
currently open parking sessions in total and broken down by vehicle category.

#### Scenario: Fetch current occupancy
- **WHEN** an admin requests `GET /reports/occupancy`
- **THEN** the system returns the total count of open sessions and a count
  per vehicle category

#### Scenario: Closed sessions are excluded from occupancy
- **WHEN** a session has `status=closed`
- **THEN** it is not counted in the occupancy report

### Requirement: Invalid date range rejected
The system SHALL reject a revenue report request where `start_date` is after
`end_date`.

#### Scenario: Start date after end date
- **WHEN** an admin requests `GET /reports/revenue` with `start_date` after
  `end_date`
- **THEN** the system rejects the request with a validation error

### Requirement: Non-admin cannot access reports
A non-admin user SHALL NOT be able to fetch the revenue or occupancy report.

#### Scenario: Operator attempts to fetch a report
- **WHEN** an authenticated operator (non-admin) requests either
  `GET /reports/revenue` or `GET /reports/occupancy`
- **THEN** the system rejects the request with a forbidden error

### Requirement: Pricing impact report
An admin SHALL be able to request, for a date range, the number of locked sessions, how many were surcharged or discounted, the extra revenue, the discounts given, the net effect and the breakdown per rule, scoped to the active lot, without changing any other revenue report.

#### Scenario: Monthly impact
- **WHEN** an admin asks for November
- **THEN** the report lists locked sessions, extra revenue and discount given

#### Scenario: Role
- **WHEN** an operator asks for it
- **THEN** the system raises `AdminRequiredError`

#### Scenario: Range
- **WHEN** the start date is after the end date
- **THEN** the system raises `InvalidReportRangeError`

### Requirement: Loyalty report
An admin SHALL be able to view a loyalty report for a date range with the members, visits counted and skipped by reason, rewards earned, redeemed and expired, the discount given and the most frequent plates, and to copy it as CSV or share it as PDF. The report SHALL be scoped to the active lot and SHALL NOT change the revenue report.

#### Scenario: View the report
- **WHEN** an admin opens `/loyalty` and selects a range
- **THEN** the figures for that range are shown with skeleton, empty and retry states

#### Scenario: Operator cannot open it
- **WHEN** an operator navigates to `/loyalty`
- **THEN** the router redirects them away

### Requirement: Monthly period comparison
The system SHALL let an admin request, for the active lot, a monthly comparison through `report_period_comparison(p_months, p_as_of)`. The response SHALL contain exactly `p_months` buckets (1 to 24, default 6), oldest first, one per calendar month in the lot's business timezone ending with the month of `p_as_of`. Every bucket SHALL carry three windows: the month (`current`), the previous calendar month (`previous_month`) and the same month one year earlier (`previous_year`). Every window SHALL report revenue, entries, exits, average ticket, average stay in minutes, monthly-pass revenue, reservations created and reservations used, computed only from rows of the active lot: revenue as the sum of `amount_charged` of closed sessions whose `exit_time` falls in the window, entries by `entry_time`, pass revenue from paid pass payments by `paid_at`, reservations by `reserved_from`.

#### Scenario: Buckets cover the trailing months
- **WHEN** an admin calls `report_period_comparison(3, '2026-11-10')`
- **THEN** the response has three buckets for 2026-09, 2026-10 and 2026-11, in that order, each with `current`, `previous_month` and `previous_year` windows

#### Scenario: Revenue is attributed to the exit month
- **WHEN** a session entered on 2026-09-30 at 23:00 and closed on 2026-10-01 at 01:00 business time with `amount_charged` 5000
- **THEN** the 5000 counts in the October `current` window revenue and not in September, while the entry counts in September entries

#### Scenario: Quiet months are returned
- **WHEN** a month inside the range had no movement
- **THEN** its bucket is present with every metric equal to 0

#### Scenario: Ticket and stay averages
- **WHEN** a window has two closed sessions charged 4000 and 6000 that lasted 60 and 120 minutes
- **THEN** its `avg_ticket` is 5000 and its `avg_stay_minutes` is 90, and a window with no exits reports 0 for both

#### Scenario: Another lot's data is excluded
- **WHEN** lot 2 has sessions in the same months and the admin calls the RPC with the `x-lot-id` of lot 1
- **THEN** no figure includes lot 2 rows

#### Scenario: Months out of range
- **WHEN** an admin calls `report_period_comparison(0, null)` or `report_period_comparison(25, null)`
- **THEN** the system raises `InvalidReportRangeError`

#### Scenario: Future reference date
- **WHEN** an admin passes a `p_as_of` later than the lot's business today
- **THEN** the system raises `InvalidReportRangeError`

### Requirement: Partial current month is compared like with like
WHILE the newest bucket is still running (its month is not complete, or `p_as_of` is the business today), the system SHALL mark it `is_partial`, SHALL count its `current` window from the first day of the month through `p_as_of` inclusive, and SHALL cut both base windows to the same number of elapsed days, capped at the base month's length. A base window that is a whole calendar month SHALL be flagged `full_month`. Windows SHALL expose `start_date`, `end_date` and `days` so a client can label them.

#### Scenario: Ten days against ten days
- **WHEN** the RPC runs on 2026-11-10 for the month 2026-11
- **THEN** the November `current` window is 2026-11-01..2026-11-10 (10 days), `previous_month` is 2026-10-01..2026-10-10 and `previous_year` is 2025-11-01..2025-11-10, and the bucket has `is_partial = true`

#### Scenario: Base month shorter than the elapsed days
- **WHEN** the RPC runs on 2026-03-31
- **THEN** `previous_month` is the whole of February 2026 (28 days) with `full_month = true`

#### Scenario: A past complete month is not partial
- **WHEN** the RPC is called with `p_as_of = '2026-10-31'` on 2026-11-10
- **THEN** the 2026-10 bucket has `is_partial = false` and its windows are whole months

#### Scenario: Leap day
- **WHEN** `p_as_of` is 2028-02-29
- **THEN** the `previous_year` window is 2027-02-01..2027-02-28 and has `full_month = true`

### Requirement: No comparison on an incomplete or empty base
The system SHALL flag each window `covered` only when the lot has had at least one session on or before the window's first day. The reports screen SHALL show a delta chip only when the base window is covered, its value is greater than zero and it has the same number of days as the compared window or is a whole month, and SHALL otherwise show the text "Sin base de comparación" instead of a chip. The delta SHALL be `round((current - base) * 100 / base)` and the chip tone SHALL be success when positive, warning when negative and neutral when zero; for average stay it SHALL always be neutral.

#### Scenario: Growth chip
- **WHEN** October revenue is 12 400 000 and September revenue is 11 800 000 on a covered base
- **THEN** the October row shows a success chip with "+5 %" against the previous month

#### Scenario: Lot younger than the base
- **WHEN** the lot's first session is 2026-03-14 and the base window starts 2025-10-01
- **THEN** the window has `covered = false` and the row shows "Sin base de comparación" with no chip

#### Scenario: Zero base
- **WHEN** the base window is covered but its revenue is 0
- **THEN** no chip is shown for revenue

#### Scenario: Flat month
- **WHEN** the current and base values are equal and the base is comparable
- **THEN** a neutral chip "Igual que el mes anterior" is shown

### Requirement: Comparison section on the reports screen
The reports screen SHALL show a "Comparación por periodo" section with a 6/12 month switch, a metric selector, a bar chart pairing each month with the same month of the previous year, a summary of the newest month with its two delta chips, and a list of months. The newest month, when partial, SHALL be labelled with the elapsed and total days ("Mes en curso · D de N días") and a "Parcial" chip. The section SHALL handle four states: loading skeleton, success, empty ("Aún no hay historial") and error with a retry action. It SHALL follow the active lot and SHALL say so when the consolidated view is selected.

#### Scenario: Success state
- **WHEN** the RPC returns buckets with movement
- **THEN** the section shows the chart, the summary and one row per month, and the metric selector changes the plotted values without a new request

#### Scenario: Switching to twelve months
- **WHEN** the admin taps the 12 months chip
- **THEN** the section shows its skeleton, the RPC is called with `p_months = 12` and the rest of the page is not reloaded

#### Scenario: Empty history
- **WHEN** every bucket has all-zero current windows
- **THEN** the section shows the empty state and no chart

#### Scenario: Failure degrades the section only
- **WHEN** the RPC fails while the revenue report succeeds
- **THEN** the page stays loaded, the section shows the error state with a retry action, and tapping retry requests the comparison again

#### Scenario: Narrow screen
- **WHEN** the page renders at 400 px width with 1.6 text scale
- **THEN** no overflow occurs and every control has a touch target of at least 48 dp

### Requirement: Comparison in exports
The CSV export SHALL include, when the comparison loaded, raw integer rows for every bucket, metric and window (current, previous month, previous year) plus the partial month and elapsed days when applicable. The PDF export SHALL include a period section with a revenue bar chart and one row per month, labelling the partial month with its day range, and SHALL use only ASCII/Latin-1 characters. Both SHALL omit the comparison when it is empty.

#### Scenario: CSV rows
- **WHEN** the admin copies the CSV with a loaded comparison
- **THEN** it contains `period_revenue,2026-10,12400000` and `period_revenue_prev_month,2026-10,11800000`

#### Scenario: Partial month in the PDF
- **WHEN** the newest bucket is partial with 10 elapsed days
- **THEN** its PDF row label states the day range 1-10 and its text has no em or en dash

#### Scenario: No comparison available
- **WHEN** the comparison failed or is empty
- **THEN** neither the CSV nor the PDF contains a period section

### Requirement: Comparison is admin-only and lot-scoped
The system SHALL refuse `report_period_comparison` to every caller that is not an admin of the active lot: operators with `AdminRequiredError`, callers without a profile or with a foreign lot header with `InvalidTokenError` or `LotRequiredError`, and the `anon` role by revoking execution. The payload SHALL contain aggregates only.

#### Scenario: Operator refused
- **WHEN** an operator calls `report_period_comparison(6, null)`
- **THEN** the system raises `AdminRequiredError`

#### Scenario: Anonymous refused
- **WHEN** a client holding only the anon key calls the RPC
- **THEN** Postgres denies execution

#### Scenario: Foreign lot header
- **WHEN** an admin who is not a member of lot 3 sends `x-lot-id: 3`
- **THEN** the system raises `LotRequiredError`

### Requirement: Merchant settlement report
An admin SHALL be able to request a settlement report for a date range, returning one row per merchant of the active lot with the validations created, applied, forfeited and revoked, the pending ones now, the discounted amount, the amount the merchant owes when its billing mode is `merchant_paid` and the courtesy amount otherwise. Validations are counted by creation date, applied and forfeited ones and all amounts by the date the session closed, revoked ones by revocation date, in the lot's business timezone. The report SHALL be scoped to the active lot and SHALL NOT change the revenue report.

#### Scenario: Fetch a monthly settlement
- **WHEN** an admin requests the settlement for November
- **THEN** each merchant shows its applied count and amount owed, and courtesy merchants show the courtesy amount with no amount owed

#### Scenario: Range boundaries
- **WHEN** a validation was applied outside the requested range
- **THEN** its amount is not counted in the range

#### Scenario: Export
- **WHEN** an admin exports the settlement
- **THEN** a CSV with raw integers and a PDF are produced from the same figures

#### Scenario: Invalid range
- **WHEN** the start date is after the end date
- **THEN** the system raises `InvalidReportRangeError`

#### Scenario: Role and lot isolation
- **WHEN** an operator requests the settlement, or an admin of another lot requests it
- **THEN** the system raises `AdminRequiredError` or returns only that lot's merchants

