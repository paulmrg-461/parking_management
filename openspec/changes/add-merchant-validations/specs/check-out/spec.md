## MODIFIED Requirements

### Requirement: Close an open session and compute its fare
An authenticated user SHALL be able to check out an open parking session by
its id, closing it with the current time as exit time and charging the fare
computed by the `billing` capability. The amount owed SHALL be produced by
`fare_quote`: the gross fare minus the automatic merchant adjustments of the
session (oldest validation first) minus the manual discount, never below zero.
The session SHALL store the gross amount, the ordered adjustment lines and the
final charge, and the response SHALL list them.

#### Scenario: Check out an open session
- **WHEN** an authenticated user checks out a session that is currently open
- **THEN** the system stamps the session's exit time as the current time,
  computes the fare for the elapsed stay via the category's tariffs, sets the
  session's status to closed, records the gross amount, the adjustments, the
  charged amount and a generated ticket number, and returns the updated session

#### Scenario: Check-out with a merchant validation
- **WHEN** the session has a pending merchant validation when it is closed
- **THEN** the validation is applied, the receipt shows the adjustment line and
  the charged amount is the amount due after the benefit

#### Scenario: No merchants configured
- **WHEN** the lot has no merchants
- **THEN** the gross amount equals the charged amount and the adjustment list is
  empty, exactly as before this change
