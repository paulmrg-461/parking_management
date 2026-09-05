# check-out Specification

## Purpose
TBD - created by archiving change check-out. Update Purpose after archive.
## Requirements
### Requirement: Close an open session and compute its fare
An authenticated user SHALL be able to check out an open parking session by
its id, closing it with the current time as exit time and charging the fare
computed by the `billing` capability.

#### Scenario: Check out an open session
- **WHEN** an authenticated user checks out a session that is currently open
- **THEN** the system stamps the session's exit time as the current time,
  computes the fare for the elapsed stay via the category's tariffs, sets the
  session's status to closed, records the charged amount and a generated
  ticket number, and returns the updated session

### Requirement: Unknown session is rejected
The system SHALL reject a check-out for a session id that does not exist.

#### Scenario: Unknown session id
- **WHEN** a user checks out a session id that has no matching parking
  session
- **THEN** the system rejects the request with a not-found error

### Requirement: Already-closed session is rejected
The system SHALL reject a check-out for a session that is already closed.

#### Scenario: Session already checked out
- **WHEN** a user checks out a session whose status is already closed
- **THEN** the system rejects the request with a conflict error

### Requirement: Unauthenticated check-out is rejected
The system SHALL reject a check-out request from an unauthenticated caller.

#### Scenario: Missing credentials
- **WHEN** an unauthenticated caller attempts to check out a session
- **THEN** the system rejects the request with an unauthorized error

