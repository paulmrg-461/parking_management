## ADDED Requirements

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
