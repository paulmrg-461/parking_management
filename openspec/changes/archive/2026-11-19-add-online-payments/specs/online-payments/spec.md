## ADDED Requirements

### Requirement: Online payment is opt-in and inert without credentials
The system SHALL offer online payment only for a lot whose `parking_settings.online_payments_enabled` is true and whose currency is COP. WHEN the payment gateway credentials or the redirect base URL are not configured in the Edge Function environment, THE SYSTEM SHALL answer `PaymentsNotConfiguredError` without touching the database, and every other feature SHALL behave as before. The system SHALL NOT allow `online_payments_enabled` to be true for a lot whose currency is not COP.

#### Scenario: Keys absent
- **WHEN** a customer asks `payment-intent` for a checkout and no `WOMPI_*` variable is set
- **THEN** the function answers 503 `PaymentsNotConfiguredError` and no intent is created

#### Scenario: Lot switch off
- **WHEN** a customer requests an intent for a session of a lot with `online_payments_enabled = false`
- **THEN** the system raises `OnlinePaymentsDisabledError` and creates nothing

#### Scenario: USD lot cannot enable the feature
- **WHEN** a lot admin sets `online_payments_enabled = true` on a lot whose currency is `USD`
- **THEN** the update is rejected by the check constraint and the setting stays false

### Requirement: Payment intents are priced by the server
WHEN a customer requests an online payment for an open session with the session id and the vehicle plate, THE SYSTEM SHALL compute the amount due on the server from the fare of the stay (`fare_breakdown`) minus what was already paid online, store it as an integer in minor units in `payment_intents.amount`, and return a pending intent. The system SHALL NOT accept an amount from the client. IF the session id or the plate is wrong, THEN the system SHALL answer `SessionNotFoundError` for both cases. IF the session is closed, THEN the system SHALL raise `SessionAlreadyClosedError`. IF nothing is due, THEN the system SHALL raise `NothingToPayError`. IF the amount is below `online_payment_min_amount`, THEN the system SHALL raise `AmountTooLowError`. IF the session has had five intents in the last hour, THEN the system SHALL raise `PaymentThrottledError`.

#### Scenario: Intent for an open session
- **WHEN** a customer with the right plate requests an intent for a stay whose fare is 6000
- **THEN** a `pending` intent with amount 6000, currency COP, a unique reference and an expiry is returned

#### Scenario: Pending intent is reused
- **WHEN** the same customer requests again while a pending intent with the same amount exists
- **THEN** the same intent is returned and no second row is created

#### Scenario: Wrong plate
- **WHEN** the plate does not belong to the session
- **THEN** the system raises `SessionNotFoundError`, identical to an unknown session

#### Scenario: Nothing due
- **WHEN** the vehicle has an active monthly pass and the fare is zero
- **THEN** the system raises `NothingToPayError`

#### Scenario: Throttle
- **WHEN** a sixth intent is requested for the same session within one hour
- **THEN** the system raises `PaymentThrottledError`

#### Scenario: Anonymous callers cannot call the intent RPC directly
- **WHEN** a client holding only the anon key calls `create_session_payment_intent`
- **THEN** Postgres denies the call with insufficient privilege

### Requirement: Confirmation only by a verified webhook
The system SHALL mark an intent as paid only when the `payment-webhook` Edge Function receives an event whose checksum verifies against `WOMPI_EVENTS_SECRET` and passes it to `apply_payment_event`. The system SHALL NOT change an intent or a session because of a browser redirect. IF the checksum is invalid, THEN the function SHALL answer 401 `InvalidSignatureError` and write nothing. IF the events secret is not configured, THEN the function SHALL answer 503 with `configured: false`.

#### Scenario: Valid approved event
- **WHEN** a correctly signed `APPROVED` event arrives for a pending intent with matching amount and currency
- **THEN** the intent becomes `approved`, the session's `online_paid_amount` increases by the amount, `online_paid_at` is stamped and the lot's members receive an `online_payment` notification

#### Scenario: Forged event
- **WHEN** an event arrives with a wrong checksum
- **THEN** the function answers 401 `InvalidSignatureError` and no row changes

#### Scenario: Redirect alone proves nothing
- **WHEN** a customer opens the return URL with a reference whose webhook has not arrived
- **THEN** `payment_intent_status` reports `pending` and the session is not marked as paid

#### Scenario: Amount mismatch
- **WHEN** a signed event carries an amount different from the intent's amount
- **THEN** the event is stored with outcome `mismatch`, nothing is marked paid and lot admins receive an `online_payment_review` notification

### Requirement: Gateway events are idempotent
The system SHALL store each gateway event once per `(gateway, gateway_transaction_id, gateway_status)` and SHALL ignore a repeated event without changing any other row. The system SHALL NOT downgrade an `approved` intent to `declined` or `error`.

#### Scenario: Duplicate delivery
- **WHEN** the same approved event is delivered twice
- **THEN** the second call returns `duplicate = true` and `online_paid_amount` is increased only once

#### Scenario: Late decline
- **WHEN** a `DECLINED` event arrives after an `APPROVED` event for the same intent
- **THEN** the intent stays `approved`

#### Scenario: Unknown reference
- **WHEN** a signed event references an unknown intent
- **THEN** the event is stored with outcome `unknown_reference`, the function answers 200 and nothing else changes

### Requirement: Late and voided payments are surfaced
WHEN an approved event arrives for a session that is already closed, THE SYSTEM SHALL record outcome `late_closed`, leave the session untouched and notify lot admins with `online_payment_review`. WHEN a `VOIDED` event arrives, THE SYSTEM SHALL mark the intent `voided`, reduce the open session's `online_paid_amount` (never below zero) and notify lot admins. WHEN an approved event arrives for an `expired` intent, THE SYSTEM SHALL still apply it.

#### Scenario: Approved after check-out
- **WHEN** the webhook approves a payment after the operator closed the session
- **THEN** the intent is `approved`, the session is unchanged and an `online_payment_review` notification exists

#### Scenario: Voided payment
- **WHEN** a `VOIDED` event arrives for an approved intent of an open session
- **THEN** the session's `online_paid_amount` drops by that amount and admins are notified

#### Scenario: Approved after expiry
- **WHEN** an intent expired and its approval then arrives
- **THEN** the payment is applied to the open session

### Requirement: Lost webhooks are reconciled
WHEN the scheduled job calls `payments-reconcile` with the service role key, THE SYSTEM SHALL look up pending intents older than ten minutes at the gateway and apply every non-pending result through the same idempotent path. The function SHALL answer 403 to any other caller and `configured: false` when credentials are absent.

#### Scenario: Approved at the gateway but webhook lost
- **WHEN** a pending intent is older than ten minutes and the gateway reports it approved
- **THEN** the reconcile call applies it and the session shows the online payment

#### Scenario: Wrong caller
- **WHEN** a request to `payments-reconcile` carries the anon key
- **THEN** the function answers 403

### Requirement: Exit grace window
The system SHALL store, per lot, the number of minutes (`online_payment_grace_minutes`, 5 to 120, default 15) a customer has to leave after paying online. WHEN a session is closed at an exit instant not later than `online_paid_at` plus that window, THE SYSTEM SHALL charge exactly the amount paid online and require no desk payment. WHEN the exit instant is later, THE SYSTEM SHALL recompute the fare for the whole stay and require at the desk only the difference between the new charge and the amount paid online.

#### Scenario: Leaves inside the window
- **WHEN** the customer paid 6000 online ten minutes ago and the fare is now 7000
- **THEN** check-out charges 6000 and the desk collects nothing

#### Scenario: Leaves after the window
- **WHEN** the customer paid 6000 online forty minutes ago and the fare is now 9000
- **THEN** check-out stores `amount_charged = 9000`, `online_paid_amount = 6000` and the desk collects 3000

#### Scenario: Window out of range
- **WHEN** an admin sets the grace to 3 minutes
- **THEN** the update is rejected by the check constraint

### Requirement: Public page shows the payment panel
WHEN the public session page loads an open session of a lot with online payments enabled and an amount due, THE SYSTEM SHALL show the amount due, the pay action and the grace minutes. WHEN the return URL carries a payment reference, THE SYSTEM SHALL poll the intent status every three seconds for at most 180 seconds and show approved, declined or still-pending. The page SHALL handle loading, nothing due, error with retry and success states.

#### Scenario: Pay panel
- **WHEN** a customer opens the QR page of an open session with 6000 due
- **THEN** the panel shows "6.000", a "Pagar en línea" action and the grace hint

#### Scenario: Approved after return
- **WHEN** the customer returns with a reference and the webhook already approved it
- **THEN** the page shows "Pago recibido" and the time before which to leave

#### Scenario: Service unavailable
- **WHEN** the intent request fails with `PaymentsNotConfiguredError`
- **THEN** the page shows a localized message telling the customer to pay at the desk, with a retry action

### Requirement: Online payments are limited to the lot's admins and the service role
The system SHALL let only lot admins read `payment_intents` of the active lot and SHALL give no authenticated role access to `payment_events`. The system SHALL list approved online payments of a window through `report_online_payments`, restricted to lot admins and to the active lot.

#### Scenario: Operator reads nothing
- **WHEN** an operator selects from `payment_intents`
- **THEN** no rows are returned

#### Scenario: Other lot is isolated
- **WHEN** an admin of lot 1 calls `report_online_payments`
- **THEN** intents of lot 2 are not listed

#### Scenario: Operator report
- **WHEN** an operator calls `report_online_payments`
- **THEN** the system raises `AdminRequiredError`
