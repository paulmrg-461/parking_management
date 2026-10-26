## ADDED Requirements

### Requirement: Check-out records how the customer paid
The system SHALL store exactly one payment method per closed session and SHALL
reject unknown methods.

#### Scenario: Card payment
- **WHEN** an operator checks out and selects card
- **THEN** the session stores `card` and the receipt shows "Tarjeta"

#### Scenario: Monthly pass overrides the selection
- **WHEN** the vehicle has an active monthly pass covering the exit date
- **THEN** the session stores `monthly_pass` and charges zero

#### Scenario: Invalid method
- **WHEN** a caller sends an unknown payment method
- **THEN** the check-out is rejected and the session stays open

### Requirement: Revenue reports include payment methods
The revenue report SHALL break down collected amounts by payment method.

#### Scenario: Revenue by payment
- **WHEN** an admin requests a revenue range
- **THEN** the response includes one amount per payment method used
