## ADDED Requirements

### Requirement: Hourly ceiling on public holds
The system SHALL keep, per parking lot, a ceiling on public holds created within the last hour (`parking_settings.public_booking_hourly_limit`, an integer from 1 to 1000, default 20). WHEN a public booking is requested and the number of holds with `source = 'public'` created in that lot during the last hour is at or above the ceiling, the system SHALL refuse it with `BookingThrottledError` and create nothing. The count SHALL include holds that were later cancelled, used or expired. The system SHALL NOT count holds created by staff and SHALL NOT apply the ceiling to them. The ceiling of one lot SHALL NOT affect another lot.

#### Scenario: Booking under the ceiling
- **WHEN** an anonymous customer books in a lot whose ceiling is 2 and no public hold was created in the last hour
- **THEN** the hold is created and returned with its code

#### Scenario: Ceiling reached
- **WHEN** two public holds were created in a lot in the last hour, the ceiling is 2 and a third public booking is requested
- **THEN** the system raises `BookingThrottledError` and no hold is created

#### Scenario: Cancelling does not reset the window
- **WHEN** the ceiling was reached and one of those holds is cancelled
- **THEN** the next public booking within the hour is still refused with `BookingThrottledError`

#### Scenario: Staff are not throttled
- **WHEN** the public ceiling of a lot is reached and an operator creates a reservation from the app
- **THEN** the reservation is created and the public window count is unchanged

#### Scenario: Another lot is unaffected
- **WHEN** lot 1 has reached its ceiling and a customer books in lot 2
- **THEN** the hold in lot 2 is created

### Requirement: Captcha requirement per lot
The system SHALL store, per parking lot, whether public booking requires a captcha (`parking_settings.public_booking_captcha`, default false). WHILE the requirement is on for a lot, the system SHALL refuse every call to the anonymous booking RPC for that lot with `CaptchaRequiredError`, whatever role the caller holds. The system SHALL create public holds for such a lot only through an RPC executable by the service role alone. WHILE the requirement is off, the anonymous booking RPC SHALL behave as before, subject to the hourly ceiling.

#### Scenario: Direct anonymous call is refused
- **WHEN** a lot requires a captcha and a client holding only the anon key calls `public_create_reservation` for it
- **THEN** the system raises `CaptchaRequiredError` and no hold is created

#### Scenario: The verified RPC is not reachable by anon
- **WHEN** a client with the `anon` or `authenticated` role calls `public_create_reservation_verified`
- **THEN** Postgres denies the call with insufficient privilege

#### Scenario: Requirement off keeps today's behaviour
- **WHEN** a lot does not require a captcha and an anonymous customer books
- **THEN** the hold is created by the anonymous RPC with no token involved

#### Scenario: Requirement is scoped to the lot
- **WHEN** lot 1 requires a captcha and lot 2 does not
- **THEN** an anonymous booking in lot 2 succeeds while the same call for lot 1 is refused

### Requirement: Lot admins configure the protection
The system SHALL let a lot admin set the captcha requirement and the hourly ceiling of the active lot through `set_public_booking_protection(p_captcha, p_hourly_limit)`, where a null argument keeps the current value. IF the ceiling is outside 1..1000, THEN the system SHALL reject the change with `InvalidDataError`. IF the caller is not an admin of the lot, THEN the system SHALL refuse the change and leave the settings as they were.

#### Scenario: Admin lowers the ceiling
- **WHEN** a lot admin calls `set_public_booking_protection(null, 2)`
- **THEN** the lot's ceiling is 2, its captcha requirement is unchanged and other lots keep their values

#### Scenario: Operator cannot change it
- **WHEN** an operator calls `set_public_booking_protection(true, 500)`
- **THEN** the call fails and the settings are unchanged

#### Scenario: Invalid ceiling
- **WHEN** an admin calls `set_public_booking_protection(null, 0)`
- **THEN** the system raises `InvalidDataError`

### Requirement: Server-side captcha verification
WHERE a Turnstile secret is configured, the `public-booking` Edge Function SHALL verify the submitted token with Cloudflare before creating a hold, and SHALL create the hold with the service role only after a successful verification. IF the token is missing, THEN the function SHALL answer `CaptchaRequiredError` without calling the database. IF Cloudflare rejects the token, THEN the function SHALL answer `CaptchaFailedError`, or `CaptchaExpiredError` when the token timed out or was already used. IF Cloudflare cannot be reached or rejects the secret, THEN the function SHALL answer `CaptchaUnavailableError` and SHALL NOT create a hold. WHERE no secret is configured, the function SHALL forward the request to the anonymous RPC with the anon key and no additional privilege. The function SHALL return the booking RPC's typed errors unchanged and SHALL NOT log the customer's name or phone.

#### Scenario: Valid token
- **WHEN** the function receives a booking with a token Cloudflare accepts
- **THEN** it calls `public_create_reservation_verified` with the service role and returns the hold

#### Scenario: Forged token
- **WHEN** the function receives a booking with a token Cloudflare rejects
- **THEN** it answers `CaptchaFailedError` and makes no database call

#### Scenario: Reused token
- **WHEN** the function receives a token Cloudflare reports as `timeout-or-duplicate`
- **THEN** it answers `CaptchaExpiredError` and makes no database call

#### Scenario: No secret configured
- **WHEN** the function has no Turnstile secret and receives a booking for a lot that requires a captcha
- **THEN** it forwards the call as anon and returns the database's `CaptchaRequiredError`

#### Scenario: Throttle through the function
- **WHEN** the verified RPC raises `BookingThrottledError`
- **THEN** the function answers HTTP 429 with that error name

### Requirement: Booking form captcha
WHERE a Turnstile site key is configured and the platform can render the widget, the booking form SHALL show the captcha above the submit action and SHALL send its token with the booking. WHERE no site key is configured or the platform cannot render the widget, the form SHALL show no captcha and SHALL book through the anonymous RPC. WHILE the captcha is shown and no valid token is held, the form SHALL NOT send a booking and SHALL tell the customer to complete the check. WHEN the token expires or the widget fails, the form SHALL discard the token and show a localized message with a retry action that renders a new challenge. WHEN a submit finishes, the form SHALL discard the token and render a new challenge. IF the server answers `BookingThrottledError`, `CaptchaRequiredError`, `CaptchaExpiredError`, `CaptchaFailedError` or `CaptchaUnavailableError`, THEN the form SHALL stay visible with a localized message in Spanish or English.

#### Scenario: No site key
- **WHEN** the page is built without a site key
- **THEN** the form shows no captcha and a booking is sent without a token

#### Scenario: Solved captcha
- **WHEN** the customer solves the captcha and submits a valid form
- **THEN** the booking is sent with the token and the confirmation is shown

#### Scenario: Submit without solving
- **WHEN** the captcha is shown, unsolved, and the customer submits a valid form
- **THEN** no request is sent and the form asks to complete the security check

#### Scenario: Token expired
- **WHEN** the widget reports that the token expired
- **THEN** the form shows the expiry message with a retry, blocks the submit, and a retry renders a new challenge

#### Scenario: Server rejects the token
- **WHEN** the server answers `CaptchaFailedError`
- **THEN** the form shows the failure message, renders a new challenge and does not resend the old token

#### Scenario: Throttled
- **WHEN** the server answers `BookingThrottledError`
- **THEN** the form shows a message asking to try again in a few minutes or call the lot
