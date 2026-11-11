## ADDED Requirements

### Requirement: Merchant settlement report
An admin SHALL be able to request a settlement report for a date range,
returning one row per merchant with the validations recorded, applied,
forfeited and revoked, the discounted amount and the amount the merchant owes
when its billing mode is `merchant_paid`. The report SHALL be scoped to the
active lot, SHALL count only validations created inside the range (business
timezone) and SHALL NOT change the revenue report.

#### Scenario: Fetch a monthly settlement
- **WHEN** an admin requests the settlement for November
- **THEN** each merchant shows its applied count and amount owed, and courtesy
  merchants show the discounted amount with no amount owed

#### Scenario: Range boundaries
- **WHEN** a validation falls outside the requested range
- **THEN** it is not counted in either the counts or the amounts

#### Scenario: Role and lot isolation
- **WHEN** an operator or an admin of another lot requests the settlement
- **THEN** the system raises `AdminRequiredError` or `LotRequiredError`
