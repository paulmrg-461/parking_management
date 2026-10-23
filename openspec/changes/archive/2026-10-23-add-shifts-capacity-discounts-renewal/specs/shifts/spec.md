## ADDED Requirements

### Requirement: Operators reconcile cash per shift
The system SHALL let an operator open one shift at a time with an opening float,
record cash withdrawals/deposits, and close it with a counted-cash
reconciliation showing expected cash and the difference.

#### Scenario: Open a shift
- **WHEN** an operator opens a shift with a 10000 float
- **THEN** only one open shift exists for that operator

#### Scenario: Close with a difference
- **WHEN** the operator closes with counted cash different from expected
- **THEN** the shift stores both amounts and the difference

#### Scenario: Check-out belongs to the shift
- **WHEN** a session is closed at an exit time covered by a shift
- **THEN** the session is linked to that shift and counted in its cash sales

### Requirement: Admins can review shifts
The system SHALL let admins list recent shifts with revenue, cash, discounts,
withdrawals/deposits and the close difference.

#### Scenario: Admin history
- **WHEN** an admin opens the shift page
- **THEN** recent shifts are listed with their reconciliation totals
