## ADDED Requirements

### Requirement: Reminder cadence for expiring passes
The system SHALL store per lot `pass_renewal_enabled` (default false) and `pass_renewal_cadence` (up to five comma-separated numbers from 0 to 30, default `7,3,1`). WHILE `pass_renewal_enabled` and `whatsapp_auto` are on for a lot, THE SYSTEM SHALL queue one WhatsApp message to the owner phone of each active pass that ends within the cadence and has no renewal, choosing for each pass the smallest cadence value not lower than the days left, and SHALL queue at most one message per pass and cadence value. The system SHALL NOT queue anything for a pass whose vehicle has no owner phone, for a pass that ended more than three days ago, or for a pass of another lot than the message's lot.

#### Scenario: Reminder three days before
- **WHEN** the scheduled job runs and an active pass ends in 3 days with cadence `7,3,1`
- **THEN** one message is queued for that pass and a second run the same day queues nothing

#### Scenario: Late run
- **WHEN** the stack was down and the job first runs when the pass ends in 2 days
- **THEN** only the message for the window of 3 days is queued, not one per missed value

#### Scenario: No phone
- **WHEN** the vehicle has no owner phone
- **THEN** nothing is queued and the in-app admin notification still exists

#### Scenario: Feature off
- **WHEN** `pass_renewal_enabled` is false or `whatsapp_auto` is false
- **THEN** no message is queued

#### Scenario: Invalid cadence
- **WHEN** an admin saves a cadence with six values or a value of 31
- **THEN** the update is rejected by the check constraint

### Requirement: Reminder without payment keys
WHEN the lot has not turned on `pass_renewal_payment_links`, THE SYSTEM SHALL queue the existing `pass_expiry` template with the plate and the end date and SHALL create no renewal offer.

#### Scenario: Reminder only
- **WHEN** links are off and a pass ends in 3 days
- **THEN** a `pass_expiry` message with `[plate, date]` is queued and no `pass_renewal_offers` row exists

#### Scenario: Link switch needs online payments
- **WHEN** an admin turns `pass_renewal_payment_links` on while `online_payments_enabled` is false
- **THEN** the update is rejected by the check constraint

### Requirement: Renewal offers carry an unguessable token
WHEN payment links are on, THE SYSTEM SHALL create at most one open renewal offer per pass holding the planned period, the amount of the pass and a random token of at least 192 bits, and SHALL queue the `pass_renewal_link` template with the token as the URL button parameter. An offer SHALL expire eight days after the pass end date.

#### Scenario: Offer created with the first reminder
- **WHEN** the job queues the first reminder for a pass with links on
- **THEN** one open offer exists with a 48-character hex token and the message carries it as `button_param`

#### Scenario: One open offer per pass
- **WHEN** the job runs again for the same pass
- **THEN** the same offer is reused

#### Scenario: Expired offer
- **WHEN** the offer is older than its expiry
- **THEN** the job marks it `expired`

### Requirement: Public renewal page
The system SHALL let an anonymous visitor with a valid token read, through `public_pass_renewal`, the lot name, the masked plate, the planned period, the amount, the currency and the offer status, and nothing else. The public page `/renew?t=<token>` SHALL show loading, ready, unavailable (unknown or expired token) and error with retry states, SHALL poll the status every three seconds for at most 180 seconds after a payment, and SHALL require no login.

#### Scenario: Valid token
- **WHEN** a visitor opens the page with a valid token
- **THEN** the page shows "ABC***", the new period and the amount and no phone number

#### Scenario: Unknown token
- **WHEN** the token does not exist
- **THEN** the RPC returns null and the page shows the unavailable state

#### Scenario: Paid
- **WHEN** the offer was settled
- **THEN** the page shows the new end date

### Requirement: Renewal payment intent
WHEN a visitor with a valid token requests payment, THE SYSTEM SHALL create a pending payment intent of kind `pass` for the offer amount through the `pass-renewal-intent` Edge Function and return the gateway checkout URL. The system SHALL refuse with `PassRenewalNotFoundError` for an unknown token, `PassRenewalPaidError` for a paid offer, `PassRenewalExpiredError` for an expired or cancelled offer, `OnlinePaymentsDisabledError` when the switches are off, `AmountTooLowError` below the minimum and `PaymentThrottledError` after five intents in an hour. WHEN payment credentials are absent, THE SYSTEM SHALL answer `PaymentsNotConfiguredError`.

#### Scenario: Intent for a valid offer
- **WHEN** a visitor requests payment for an open offer of 90000
- **THEN** a pending intent of 90000 with a reference and a checkout URL is returned

#### Scenario: Paid offer
- **WHEN** the offer is already paid
- **THEN** the function answers 409 `PassRenewalPaidError` and no intent is created

#### Scenario: Keys absent
- **WHEN** no payment key is configured
- **THEN** the function answers 503 `PaymentsNotConfiguredError` and the page tells the customer to renew at the desk

#### Scenario: Direct RPC call
- **WHEN** a client with the anon key calls `create_pass_renewal_intent`
- **THEN** Postgres denies the call

### Requirement: Approved payment renews the pass once
WHEN the verified webhook approves a `pass` intent, THE SYSTEM SHALL create the linked next pass (same vehicle, lot, amount and auto-renew settings, `renewed_from_id` set, starting at the later of the planned start and the lot's local today), mark its charge `paid` with method `online`, mark the offer `paid` and notify the lot's members. The system SHALL NOT create a second renewal for the same pass and SHALL NOT attach the online charge to any cash shift. IF a renewal already exists with a pending charge (created by the expiry job), THEN the system SHALL mark that charge paid instead of creating a pass. IF the renewal is already paid, THEN the system SHALL record the event as `late_closed` and notify lot admins for review.

#### Scenario: Early renewal
- **WHEN** a payment is approved three days before the pass ends
- **THEN** a new active pass starts the day after the end date, its charge is `paid` online and the offer is `paid`

#### Scenario: Duplicate event
- **WHEN** the same approved event is delivered twice
- **THEN** only one renewal pass exists

#### Scenario: Expiry job ran first
- **WHEN** the expiry job already created the renewal with a pending charge and the customer then pays
- **THEN** that charge becomes `paid` online and no additional pass is created

#### Scenario: Paid after expiry
- **WHEN** the payment is approved two days after the end date
- **THEN** the new pass starts on the lot's local today

#### Scenario: Not part of the cash drawer
- **WHEN** a renewal is paid online during an open shift
- **THEN** the shift's `pass_cash_sales` and `expected_cash` do not change

#### Scenario: Revenue still counts it
- **WHEN** an admin requests the revenue report for that day
- **THEN** `pass_revenue` includes the renewal and `pass_by_payment` shows it under `online`

### Requirement: Admin sends a renewal link manually
WHEN a lot admin requests `send_pass_renewal_link` for a pass, THE SYSTEM SHALL create or reuse the open offer and queue one message, at most once per day per offer. The system SHALL raise `PassNotFoundError` for an unknown pass or a pass of another lot, `PassRenewalDisabledError` when the switches are off, `WhatsappDisabledError` when automated WhatsApp is off, `MissingOwnerPhoneError` without a phone and `PassAlreadyRenewedError` when a renewal exists. The Flutter action SHALL be unavailable offline and SHALL NOT be queued.

#### Scenario: Manual send
- **WHEN** an admin sends the link for a pass whose owner has a phone
- **THEN** one message is queued and a second press the same day queues none

#### Scenario: Operator
- **WHEN** an operator calls `send_pass_renewal_link`
- **THEN** the system raises `AdminRequiredError`

#### Scenario: Other lot
- **WHEN** an admin of lot 1 targets a pass of lot 2
- **THEN** the system raises `PassNotFoundError`

#### Scenario: Offline
- **WHEN** the device is offline
- **THEN** the app shows a localized network error and nothing is queued

### Requirement: Admins see the renewal state of each pass
The monthly passes list SHALL show "Enlace enviado" for a pass with an open offer that had reminders and "Renovada en línea" for a pass renewed through an offer. Only lot admins SHALL read renewal offers.

#### Scenario: Chip
- **WHEN** a pass has an open offer with one reminder sent
- **THEN** its tile shows the link-sent chip

#### Scenario: Operator reads nothing
- **WHEN** an operator selects from `pass_renewal_offers`
- **THEN** no rows are returned
