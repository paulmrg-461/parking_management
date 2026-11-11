## ADDED Requirements

### Requirement: Merchant settlement report
An admin SHALL be able to request a settlement report for a date range, returning one row per merchant of the active lot with the validations created, applied, forfeited and revoked, the pending ones now, the discounted amount, the amount the merchant owes when its billing mode is `merchant_paid` and the courtesy amount otherwise. Validations are counted by creation date, applied and forfeited ones and all amounts by the date the session closed, revoked ones by revocation date, in the lot's business timezone. The report SHALL be scoped to the active lot and SHALL NOT change the revenue report.

#### Scenario: Fetch a monthly settlement
- **WHEN** an admin requests the settlement for November
- **THEN** each merchant shows its applied count and amount owed, and courtesy merchants show the courtesy amount with no amount owed

#### Scenario: Range boundaries
- **WHEN** a validation was applied outside the requested range
- **THEN** its amount is not counted in the range

#### Scenario: Export
- **WHEN** an admin exports the settlement
- **THEN** a CSV with raw integers and a PDF are produced from the same figures

#### Scenario: Invalid range
- **WHEN** the start date is after the end date
- **THEN** the system raises `InvalidReportRangeError`

#### Scenario: Role and lot isolation
- **WHEN** an operator requests the settlement, or an admin of another lot requests it
- **THEN** the system raises `AdminRequiredError` or returns only that lot's merchants
