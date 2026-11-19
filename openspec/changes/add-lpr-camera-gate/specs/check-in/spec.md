## ADDED Requirements

### Requirement: Check-in on behalf of a recognised plate
The system SHALL allow a session to be opened for a plate recognised by a camera through the same `check_in` rules (capacity, blacklist, reservation conversion, bay selection, auto-registration of unknown plates with a category), attributed either to the lot's configured system operator (automatic mode) or to the confirming operator (assist mode). The snapshot of the read SHALL be attached as an evidence photo of the session without requiring a Storage object owned by the caller. A plate corrected by the operator SHALL be normalized with the same rule as manual entry.

#### Scenario: Evidence photo from the camera
- **WHEN** an entry event with a snapshot results in a session
- **THEN** the session lists one evidence photo whose path starts with `lpr/`

#### Scenario: Same rules as manual entry
- **WHEN** a recognised plate belongs to a blacklisted vehicle or the category is full
- **THEN** no session is opened and the corresponding typed error is recorded in the event

#### Scenario: Reservation is honoured
- **WHEN** a recognised plate has an active reservation in the lot
- **THEN** the hold becomes `used` and the session opens like a manual check-in

## MODIFIED Requirements

### Requirement: Unauthenticated check-in is rejected
The system SHALL reject a check-in request that carries neither a signed-in app
user nor a valid device credential: a human caller without a GoTrue session,
and a device request whose `X-Device-Key` is missing, unknown, revoked or fails
the replay, clock or rate checks. A check-in performed on behalf of a camera
read SHALL be authenticated by the device gateway (kind `camera`) and
attributed to the lot's configured system operator or to the confirming
operator; it never requires a user session and never accepts a `user_id` or
`lot_id` from the caller.

#### Scenario: Missing user credentials
- **WHEN** a caller without a session calls `check_in` directly
- **THEN** the system rejects the request with an unauthorized error
  (`InvalidTokenError`)

#### Scenario: Missing device credentials
- **WHEN** a request reaches the device gateway without `X-Device-Key` or with
  an unknown or revoked key
- **THEN** the gateway answers 401, records `invalid-key` in `device_events`
  and no session is created

#### Scenario: Device check-in is attributed to the system operator
- **WHEN** a camera read above the confidence threshold triggers an automatic
  entry
- **THEN** the session is created by `check_in` with the lot's configured system
  operator as `operator_id`, never a user id supplied by the device

#### Scenario: Device check-in keeps every business rule
- **WHEN** a camera read arrives for a plate whose category or group is full
- **THEN** `check_in` refuses it with the same error a manual entry gets and the
  event is left pending for the operator
