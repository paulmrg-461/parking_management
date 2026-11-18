# reports Specification

## Purpose
TBD - created by archiving change reports. Update Purpose after archive.
## Requirements
### Requirement: Revenue report
An admin SHALL be able to request a revenue report for a date range, returning
the total charged amount, a breakdown by calendar day, and a breakdown by
vehicle category, computed from closed sessions whose exit time falls within
the range (inclusive, end date treated as end-of-day).

#### Scenario: Fetch revenue for a range
- **WHEN** an admin requests `GET /reports/revenue` with a `start_date` and
  `end_date`
- **THEN** the system returns the total revenue, an amount per calendar day,
  and an amount per category, counting only closed sessions whose exit time
  falls within `[start_date, end_date]`

#### Scenario: Sessions outside the range are excluded
- **WHEN** a closed session's exit time falls before `start_date` or after
  `end_date`
- **THEN** its `amount_charged` is not included in the report total, day
  breakdown, or category breakdown

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

