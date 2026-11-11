## ADDED Requirements

### Requirement: Charged amounts are tax-inclusive
The system SHALL treat every stored charge (`amount_charged`, pass charge amounts) as the total the customer pays, tax included, and SHALL derive the tax for fiscal documents from that total with the lot's configured rate, never altering the fare calculation or the amount charged. The tax base SHALL equal the total times 10000 divided by (10000 plus the rate in basis points), rounded to the nearest peso, and the tax SHALL equal the total minus the tax base.

#### Scenario: Tax extracted from the charge
- **WHEN** a session was charged 11900 and the lot rate is 1900 basis points
- **THEN** the fiscal document shows tax base 10000, tax 1900 and total 11900

#### Scenario: Fare unchanged
- **WHEN** invoicing is switched on for a lot
- **THEN** `calculate_fare` and `check_out` return the same amounts as before

#### Scenario: Zero rate
- **WHEN** the lot rate is 0
- **THEN** the tax base equals the total and the tax is 0
