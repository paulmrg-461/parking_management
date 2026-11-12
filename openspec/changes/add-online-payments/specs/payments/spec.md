## MODIFIED Requirements

### Requirement: Check-out records how the customer paid
The system SHALL store exactly one payment method per closed session and
SHALL reject unknown methods. The method `online` SHALL be assigned only by the
server when the customer paid the whole amount through an online payment; a
caller that sends `online` SHALL be rejected.

#### Scenario: Card payment
- **WHEN** an operator checks out and selects card
- **THEN** the session stores `card` and the receipt shows "Tarjeta"

#### Scenario: Monthly pass overrides the selection
- **WHEN** the vehicle has an active monthly pass covering the exit date
- **THEN** the session stores `monthly_pass` and charges zero

#### Scenario: Invalid method
- **WHEN** a caller sends an unknown payment method
- **THEN** the check-out is rejected and the session stays open

#### Scenario: Paid online
- **WHEN** a session with a completed online payment is closed inside the grace window
- **THEN** the session stores `online`, the amount charged equals the amount paid online and the receipt shows "En línea"

#### Scenario: Caller cannot choose online
- **WHEN** an operator calls check-out with payment method `online`
- **THEN** the check-out is rejected with `InvalidPaymentMethod` and the session stays open

### Requirement: Revenue reports include payment methods
The revenue report SHALL break down collected amounts by payment method. Money
collected online SHALL appear as its own `online` entry, and the other methods
SHALL show only what was collected at the desk, so that the entries add up to
the total.

#### Scenario: Revenue by payment
- **WHEN** an admin requests a revenue range
- **THEN** the response includes one amount per payment method used

#### Scenario: Partly online
- **WHEN** a session of 9000 was paid 6000 online and 3000 in cash
- **THEN** `by_payment` shows 6000 under `online` and 3000 under `cash`, and `total` includes 9000

## ADDED Requirements

### Requirement: Online payments are listed for bank reconciliation
The system SHALL let a lot admin list, for a date range in the lot's business timezone, the approved and voided online payments with reference, gateway transaction id, method, amount, approval time, plate and ticket.

#### Scenario: Admin lists a day
- **WHEN** an admin requests `report_online_payments` for today
- **THEN** each approved payment appears once with its transaction id and the response total equals their sum
