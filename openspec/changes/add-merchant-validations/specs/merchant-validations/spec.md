## ADDED Requirements

### Requirement: Merchant registry and benefit
The system SHALL let an admin of the lot register merchants with a name, exactly
one benefit rule (`free_minutes`, `percentage` or `fixed_amount`, with an
optional cap per validation), a billing mode (`merchant_paid` or `courtesy`),
optional daily and monthly validation ceilings, and an active flag. A merchant
name SHALL be unique inside the lot. Every create, edit, key rotation, disable
and delete SHALL be written to `audit_log` with the actor.

#### Scenario: Create a merchant
- **WHEN** an admin creates "Café Central" with 30 free minutes and
  `merchant_paid`
- **THEN** the merchant exists for the lot, inactive credentials are not
  required, and the audit log records the creation

#### Scenario: Duplicate name in the lot
- **WHEN** an admin creates a second merchant with the same name in the same lot
- **THEN** the system raises `DuplicateMerchantError`

#### Scenario: Operator cannot manage merchants
- **WHEN** an operator calls `save_merchant`
- **THEN** the system raises `AdminRequiredError`

### Requirement: Merchant credential (link token and PIN)
The system SHALL issue a private link token (shown once) and a 6-digit PIN per
merchant, storing only their SHA-256 hashes. An admin SHALL be able to rotate
the token or set a new PIN, invalidating the previous one. Five wrong PIN
attempts SHALL lock the merchant for 15 minutes; a successful validation SHALL
reset the counter.

#### Scenario: Correct token and PIN
- **WHEN** the merchant opens `/validate?m=<token>` and enters its PIN
- **THEN** the page shows the merchant name and its benefit summary

#### Scenario: Wrong PIN five times
- **WHEN** five validations with the wrong PIN happen within the lock window
- **THEN** the next attempt raises `MerchantLockedError` until the lock expires

#### Scenario: Rotated token
- **WHEN** an admin rotates the token
- **THEN** the previous link returns `MerchantNotFoundError` and the new one
  works

#### Scenario: Unknown token
- **WHEN** a request arrives with a token that matches no merchant
- **THEN** the system answers as if the merchant did not exist (no enumeration)

### Requirement: Public validation page
A merchant SHALL be able to record one validation for a plate from a public,
account-free page: the page SHALL ask for the plate (typed or read from the
entry receipt QR) and the PIN, and the server SHALL resolve the open session of
that plate in the merchant's lot. The response SHALL carry only the merchant
name, the applied benefit amount and a status; it SHALL never expose session
ids, plates of other vehicles or money of other sessions.

#### Scenario: Validate an open session
- **WHEN** the cashier validates plate ABC123, which has an open session, with
  the correct PIN
- **THEN** one `pending` validation exists for that session and merchant and the
  page says the benefit was registered

#### Scenario: Plate without an open session
- **WHEN** the cashier validates a plate that is not inside
- **THEN** the system raises `SessionNotFoundError` and nothing is recorded

#### Scenario: Already validated by this merchant
- **WHEN** the same merchant validates the same session twice
- **THEN** the system raises `AlreadyValidatedError`

#### Scenario: Caps
- **WHEN** the merchant already reached its daily ceiling
- **THEN** the system raises `MerchantCapError`

### Requirement: Desk validation
An operator SHALL be able to register a merchant validation for an open session
from the check-out dialog, under the same uniqueness, ceiling and
`merchant_max_per_session` rules as the public page. The validation SHALL record
the operator as its author.

#### Scenario: Validate from the desk
- **WHEN** an operator picks "Café Central" while checking out ABC123
- **THEN** a validation with `source = 'desk'` and the operator as `created_by`
  is recorded and listed in the preview

#### Scenario: Per-session limit
- **WHEN** the session already has `merchant_max_per_session` validations
- **THEN** the system raises `MerchantLimitError`

### Requirement: Single source of the amount owed
The system SHALL compute the amount a session owes in one place (`fare_quote`),
used by check-out, the check-out preview, the public session page and the
history reprint. It SHALL return the gross amount, the ordered adjustment lines,
the manual discount and the amount due, never below zero.

#### Scenario: Free minutes
- **WHEN** a 2-hour stay of 10000 gets 30 free minutes from a merchant
- **THEN** the quote charges 90 minutes (ceil to the next hour as billing does)
  and lists the adjustment amount

#### Scenario: Percentage with a cap
- **WHEN** a 10000 stay gets a 50% benefit capped at 3000
- **THEN** the adjustment is 3000, not 5000

#### Scenario: Manual discount applied last
- **WHEN** a session has a 3000 merchant adjustment and a 2000 manual discount
- **THEN** the amount due is the gross minus 5000, never below zero

#### Scenario: Discount above the amount due
- **WHEN** the manual discount exceeds the amount due after the adjustments
- **THEN** the system raises `InvalidDiscountError`

### Requirement: Applied at check-out and visible everywhere
When a session with pending validations is closed, the system SHALL apply them,
store the gross amount, the adjustment lines and the final charge, mark the
validations `applied` (or `forfeited` when they could not be used) and SHOW the
benefit in the check-out receipt, the PDF and thermal print, the history
reprint and the public session page.

#### Scenario: Close with a validation
- **WHEN** the operator closes the session of a validated plate
- **THEN** the receipt lists "Convenio <merchant>: −$X", the session stores
  `gross_amount`, `fare_adjustments` and `amount_charged = amount due`, and the
  validation becomes `applied`

#### Scenario: Reprint keeps the numbers
- **WHEN** the receipt is reprinted from the vehicle history
- **THEN** the same gross, adjustments and total are printed without recomputing

#### Scenario: Public page shows the benefit
- **WHEN** the customer opens the receipt QR page after the validation
- **THEN** the summary lists the merchant benefit and the amount due

### Requirement: Revocation
A lot admin SHALL be able to revoke a pending validation with a reason while
its session is open. Revoking an applied validation SHALL be refused (the
document and the receipt are already issued).

#### Scenario: Revoke while open
- **WHEN** an admin revokes a pending validation with a reason
- **THEN** the row is `revoked`, the reason and actor are stored, the audit log
  records it and the check-out no longer applies the benefit

#### Scenario: Revoke after close
- **WHEN** an admin tries to revoke a validation whose session is closed
- **THEN** the system raises `ValidationNotRevocableError`

### Requirement: Settlement report
An admin SHALL be able to request, for a date range, a per-merchant settlement:
validations recorded, applied, forfeited and revoked, the discounted amount and
the amount the merchant owes when its billing mode is `merchant_paid`. The
report SHALL be lot-scoped and SHALL NOT change any other revenue report.

#### Scenario: Monthly settlement
- **WHEN** an admin asks for November
- **THEN** each merchant shows its applied count and the amount owed, summing
  only applied validations of that range

#### Scenario: Courtesy merchants
- **WHEN** the merchant's billing mode is `courtesy`
- **THEN** the report shows the discounted amount but no amount owed

#### Scenario: Other lot
- **WHEN** an admin of another lot requests the report
- **THEN** the system raises `LotRequiredError`

### Requirement: Inert without merchants
With no merchant configured for the lot, check-out, the preview, the public
session page and the history SHALL behave exactly as today: no adjustment
lines, no new columns filled, no new required input.

#### Scenario: No merchants
- **WHEN** the lot has no merchants and a session is closed
- **THEN** the quote returns `adjustments: []` and the amount equals the
  previous behaviour
