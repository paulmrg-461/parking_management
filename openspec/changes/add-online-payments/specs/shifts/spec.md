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
