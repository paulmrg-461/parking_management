## ADDED Requirements

### Requirement: Merchant registry and benefit
The system SHALL let an admin of the lot register merchants with a name, exactly one benefit rule (`free_minutes` 1..1440, `percentage` 1..100 or `fixed_amount` >= 1, with an optional cap per validation), a billing mode (`merchant_paid` or `courtesy`), optional daily and monthly validation ceilings and an active flag. A merchant name SHALL be unique inside the lot. Every create, edit, credential reset and delete SHALL be written to `audit_log` with the actor and SHALL NOT contain any secret.

#### Scenario: Create a merchant
- **WHEN** an admin creates "Cafe Central" with 30 free minutes and `merchant_paid`
- **THEN** the merchant exists for the lot, a link token and a 6-digit PIN are returned once, and the audit log records the creation without any hash

#### Scenario: Duplicate name in the lot
- **WHEN** an admin creates a second merchant with the same name in the same lot
- **THEN** the system raises `DuplicateMerchantError`

#### Scenario: Invalid benefit
- **WHEN** an admin saves a percentage of 101, free minutes of 0 or an empty name
- **THEN** the system raises `InvalidDataError` and stores nothing

#### Scenario: Operator cannot manage merchants
- **WHEN** an operator calls `save_merchant`, `reset_merchant_credentials`, `delete_merchant` or `set_merchant_policy`
- **THEN** the system raises `AdminRequiredError`

#### Scenario: Merchant with validations is not deleted
- **WHEN** an admin deletes a merchant that has any validation
- **THEN** the system raises `MerchantInUseError` and the merchant can be disabled instead

### Requirement: Merchant credentials
The system SHALL issue a private link token (shown once) and a server-generated 6-digit PIN per merchant, storing only a SHA-256 hash of the token and a salted bcrypt hash of the PIN in a table that has no policy, no grant and no audit trigger. An admin SHALL be able to generate a new PIN or a new token and PIN, invalidating the previous ones. Five wrong PIN attempts SHALL lock the merchant for 15 minutes; a correct PIN SHALL reset the counter. A wrong PIN SHALL be answered with a status, never an exception, so the counter is committed.

#### Scenario: Correct token and PIN
- **WHEN** the cashier opens `/validate?m=<token>` and enters the PIN with a plate that is inside
- **THEN** the page shows the merchant name and the benefit that was registered

#### Scenario: Wrong PIN persists the attempt
- **WHEN** a wrong PIN is sent
- **THEN** the answer is `invalid_pin` with the attempts left and `pin_failures` is incremented in the database

#### Scenario: Five wrong PINs lock the merchant
- **WHEN** five wrong PINs are sent in a row
- **THEN** the answer is `locked` with a `locked_until` about 15 minutes ahead, and a correct PIN is also answered `locked` until it passes

#### Scenario: Rotated token
- **WHEN** an admin rotates the token
- **THEN** the previous link raises `MerchantNotFoundError` and the new one works

#### Scenario: Unknown token
- **WHEN** a request arrives with a token that matches no active merchant
- **THEN** `merchant_portal` answers null and `merchant_validate` raises `MerchantNotFoundError`, identically for unknown, rotated and inactive merchants

#### Scenario: Secrets never reach the audit log
- **WHEN** a merchant is created and its credentials are reset
- **THEN** no `audit_log` row contains a token hash or a PIN hash

### Requirement: Public validation page
A merchant SHALL be able to record one validation for a plate from a public account-free page: the page SHALL ask for the plate (typed or read from the entry receipt QR) and the PIN, and the server SHALL resolve the OPEN session of that plate in the merchant's lot. The response SHALL carry only the merchant name, the benefit and a status; it SHALL never expose session ids, plates, or money.

#### Scenario: Validate an open session
- **WHEN** the cashier validates plate ABC123, which has an open session in the merchant's lot, with the correct PIN
- **THEN** one `pending` validation with `source = 'public'` and a null author exists for that session and merchant, with the benefit terms snapshotted

#### Scenario: Plate without an open session
- **WHEN** the cashier validates a plate that is not inside, is only reserved, or is inside another lot
- **THEN** the system raises `SessionNotFoundError` and nothing is recorded

#### Scenario: Already validated by this merchant
- **WHEN** the same merchant validates the same session twice
- **THEN** the system raises `AlreadyValidatedError`

#### Scenario: Pass holder
- **WHEN** the vehicle holds an active monthly pass
- **THEN** the system raises `SessionNotEligibleError`

#### Scenario: Caps
- **WHEN** the merchant already reached its daily or monthly ceiling, counting non-revoked validations of the current business day or month of the lot
- **THEN** the system raises `MerchantCapError`

#### Scenario: Anonymous callers cannot read tables
- **WHEN** the `anon` role selects from `merchants`, `merchant_validations` or `merchant_credentials`
- **THEN** Postgres denies the read with insufficient privilege

### Requirement: Desk validation
An operator SHALL be able to register a merchant validation for an open session of the active lot from the check-out dialog, under the same uniqueness, ceiling and `merchant_max_per_session` rules as the public page. The validation SHALL record the operator as its author and the answer SHALL include the fare quote with the new adjustment.

#### Scenario: Validate from the desk
- **WHEN** an operator picks "Cafe Central" while checking out ABC123 and applies it
- **THEN** a validation with `source = 'desk'` and the operator as `created_by` is recorded and the returned quote lists the adjustment

#### Scenario: Per-session limit
- **WHEN** the session already has `merchant_max_per_session` non-revoked validations (or the setting is 0)
- **THEN** the system raises `MerchantLimitError`

#### Scenario: Other lot
- **WHEN** an operator validates a session of another lot
- **THEN** the system raises `LotRequiredError`, and a merchant of another lot raises `MerchantNotFoundError`

### Requirement: Single source of the amount owed
The system SHALL compose the amount a session owes in one internal function (`fare_quote`), used by check-out, the check-out preview, the public session page and the history reprint, following the normative composition in `design.md`: base fare, the dynamic-pricing hook, merchant lines oldest first, the loyalty hook, the manual admin discount last, never below zero. The function SHALL NOT be executable by API roles and SHALL expose two replaceable no-op hooks (`fare_pricing_step`, `fare_reward_step`).

#### Scenario: Percentage
- **WHEN** a 09:00 to 11:30 stay of base 9000 has a 50% merchant validation
- **THEN** the quote has one adjustment of 4500 and `amount_due = 4500`

#### Scenario: Free minutes
- **WHEN** the same stay has 30 free minutes
- **THEN** the shortened stay of 2 hours is re-billed at 6000, the adjustment is 3000, and with an exit at 11:40 the adjustment is 0 and the validation is forfeited

#### Scenario: Cap per validation
- **WHEN** a base of 20000 gets a 50% benefit with `max_amount` 8000
- **THEN** the adjustment is 8000

#### Scenario: Two merchants, oldest first
- **WHEN** a fixed 2000 validation created first and a 50% validation created second apply to a base of 9000
- **THEN** the lines are 2000 then 3500 and the amount due is 3500

#### Scenario: Manual discount last
- **WHEN** a session has a 3000 merchant adjustment and a 2000 manual discount on a 9000 base
- **THEN** the amount due is 4000

#### Scenario: Discount above the running amount
- **WHEN** the manual discount exceeds the amount left after the adjustments
- **THEN** the system raises `InvalidDiscountError`

#### Scenario: Lost ticket and pass holder
- **WHEN** the session is closed as a lost ticket or the vehicle holds an active pass
- **THEN** no merchant adjustment is applied, the validations are forfeited, a lost ticket still honours the admin discount and a pass holder owes 0

#### Scenario: Hooks are inert by default
- **WHEN** neither dynamic pricing nor loyalty is installed
- **THEN** the quote has `pricing = null`, `reward = null` and the amounts depend on merchants only

#### Scenario: Internal functions are not callable
- **WHEN** an operator or anonymous caller calls `fare_quote`, `fare_pricing_step` or `fare_reward_step`
- **THEN** Postgres denies the call with insufficient privilege

### Requirement: Applied at check-out and visible everywhere
When a session with pending validations is closed, the system SHALL apply them inside the same transaction, store `gross_amount`, the ordered adjustment lines and the final charge, mark each validation `applied` (with its amount) or `forfeited` when it produced no line, and SHALL show the benefit in the check-out receipt (screen, PDF, thermal), the history reprint and the public session page. A queued check-out SHALL be quoted at the instant the operator confirmed (`client_exit_time`).

#### Scenario: Close with a validation
- **WHEN** the operator closes the session of a validated plate
- **THEN** the receipt lists the merchant line, the session stores `gross_amount`, `fare_adjustments` and `amount_charged`, and the validation becomes `applied` with its amount

#### Scenario: Reprint keeps the numbers
- **WHEN** the receipt is reprinted from the vehicle history
- **THEN** the same gross, adjustments and total are printed without recomputing

#### Scenario: Public page shows the benefit
- **WHEN** the customer opens the receipt QR page after the validation
- **THEN** the summary lists the merchant benefit and the amount due, and exposes no merchant or validation internals

#### Scenario: Offline exit instant
- **WHEN** a check-out queued offline is replayed with a `client_exit_time` two hours old
- **THEN** the quote, including the free-minutes shortening, uses that instant

#### Scenario: Pending-sync receipt
- **WHEN** a check-out is still queued offline
- **THEN** the receipt shows no amount and no adjustment

### Requirement: Revocation
A lot admin SHALL be able to revoke a pending validation with a reason of 3 to 200 characters while its session is open. Revoking an applied, forfeited or revoked validation, or one whose session is closed, SHALL be refused. A revoked validation SHALL no longer count toward the per-session limit or the merchant ceilings.

#### Scenario: Revoke while open
- **WHEN** an admin revokes a pending validation with a reason
- **THEN** the row is `revoked`, the reason, actor and instant are stored, the audit log records it and the quote no longer applies it

#### Scenario: Revoke after close
- **WHEN** an admin tries to revoke a validation whose session is closed
- **THEN** the system raises `ValidationNotRevocableError`

#### Scenario: Reason required
- **WHEN** the reason has fewer than 3 or more than 200 characters
- **THEN** the system raises `RevokeReasonRequiredError`

#### Scenario: Operator cannot revoke
- **WHEN** an operator calls `revoke_merchant_validation`
- **THEN** the system raises `AdminRequiredError`

### Requirement: Inert without merchants
With no merchant configured for the lot, check-out, the preview, the public session page and the history SHALL behave exactly as before: no adjustment lines, an empty adjustment list, `gross_amount` equal to the charge, and no new required input.

#### Scenario: No merchants
- **WHEN** the lot has no merchants and a session is closed
- **THEN** the quote returns `adjustments: []` and the amount equals the previous behaviour

### Requirement: Zero charge explained by automatic lines
The system SHALL treat a closed session as an explained zero charge for cash anomaly detection when `gross_amount > 0`, `discount_amount = 0` and the sum of its `fare_adjustments` amounts equals `gross_amount`, whatever the type of the lines.

#### Scenario: Fully covered by a merchant
- **WHEN** a merchant benefit takes the whole gross fare
- **THEN** `anomaly_zero_charge_excluded` is true for the session

#### Scenario: Plain zero charge
- **WHEN** a session closes at 0 with no adjustment lines, or with a manual discount
- **THEN** `anomaly_zero_charge_excluded` is false
