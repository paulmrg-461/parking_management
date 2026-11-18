## ADDED Requirements

### Requirement: Loyalty report
An admin SHALL be able to view a loyalty report for a date range with the members, visits counted and skipped by reason, rewards earned, redeemed and expired, the discount given and the most frequent plates, and to copy it as CSV or share it as PDF. The report SHALL be scoped to the active lot and SHALL NOT change the revenue report.

#### Scenario: View the report
- **WHEN** an admin opens `/loyalty` and selects a range
- **THEN** the figures for that range are shown with skeleton, empty and retry states

#### Scenario: Operator cannot open it
- **WHEN** an operator navigates to `/loyalty`
- **THEN** the router redirects them away
