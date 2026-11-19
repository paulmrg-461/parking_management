## MODIFIED Requirements

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
