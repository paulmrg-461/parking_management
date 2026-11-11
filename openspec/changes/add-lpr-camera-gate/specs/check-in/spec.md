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
