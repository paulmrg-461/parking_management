## ADDED Requirements

### Requirement: Online payments never enter the cash drawer
The system SHALL report, for each shift, `online_sales` as the sum of `online_paid_amount` of the sessions closed in it, and SHALL compute `cash_sales`, `card_sales`, `transfer_sales` and `exempt_sales` from the amount collected at the desk only (amount charged minus the online part). The system SHALL NOT include online money in `expected_cash`. The revenue of the shift SHALL equal the sum of the desk methods, the pass sales and `online_sales`.

#### Scenario: Cash session partly paid online
- **WHEN** a 9000 session paid 6000 online is closed with cash
- **THEN** the shift's `cash_sales` increases by 3000, `online_sales` by 6000 and `expected_cash` by 3000

#### Scenario: Fully online session
- **WHEN** a session paid fully online is closed
- **THEN** the shift's `expected_cash` is unchanged and `online_sales` includes the amount

#### Scenario: Close with counted cash
- **WHEN** the operator closes the shift
- **THEN** the difference is computed against an expected cash that excludes online money

#### Scenario: Shift totals stay lot scoped
- **WHEN** an admin of another lot asks for the totals of the shift
- **THEN** the system raises `LotRequiredError`

### Requirement: Shift screen and PDF show online payments
The shift screen and the shift PDF SHALL show the online sales as a separate line from cash, card and transfer.

#### Scenario: Separate line
- **WHEN** a closed shift has 6000 in `online_sales`
- **THEN** the screen and the PDF show "Pagos en línea" with 6.000

## MODIFIED Requirements

### Requirement: Operators reconcile cash per shift
The system SHALL let an operator open one shift at a time with an opening
float, record cash withdrawals/deposits, and close it with a counted-cash
reconciliation showing expected cash and the difference. Expected cash SHALL
count only money collected at the desk: the online part of a session paid
through the gateway never enters the drawer, and the shift reports it as its
own `online_sales` line.

#### Scenario: Open a shift
- **WHEN** an operator opens a shift with a 10000 float
- **THEN** only one open shift exists for that operator

#### Scenario: Close with a difference
- **WHEN** the operator closes with counted cash different from expected
- **THEN** the shift stores both amounts and the difference

#### Scenario: Check-out belongs to the shift
- **WHEN** a session is closed at an exit time covered by a shift
- **THEN** the session is linked to that shift and its desk portion is counted
  in the shift's cash sales

#### Scenario: Online money stays out of the drawer
- **WHEN** a session paid 6000 online and 3000 in cash closes inside the shift
- **THEN** the shift's cash sales grow by 3000, `online_sales` by 6000 and the
  expected cash by 3000
