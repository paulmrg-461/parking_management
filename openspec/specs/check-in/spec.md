# check-in Specification

## Purpose
TBD - created by archiving change check-in. Update Purpose after archive.
## Requirements
### Requirement: Check in a vehicle
An authenticated user SHALL be able to check in a vehicle by plate, opening a
parking session and optionally attaching evidence photos.

#### Scenario: Check in an existing vehicle
- **WHEN** an authenticated user checks in a vehicle with a known plate and one
  or more photos
- **THEN** the system creates an open parking session with the current time as
  entry time, stores each photo, and returns the session with its photos

#### Scenario: Check in without photos
- **WHEN** an authenticated user checks in a vehicle with a known plate and no
  photos
- **THEN** the system creates the open parking session with no evidence photos

### Requirement: Unknown plate is rejected
The system SHALL reject a check-in for a plate that does not match any
registered vehicle.

#### Scenario: Unknown plate
- **WHEN** a user checks in a plate that has no matching vehicle
- **THEN** the system rejects the request with a not-found error

### Requirement: Duplicate open session is rejected
The system SHALL reject a check-in for a vehicle that already has an open
parking session.

#### Scenario: Vehicle already checked in
- **WHEN** a user checks in a vehicle that already has an open session
- **THEN** the system rejects the request with a conflict error

### Requirement: List open sessions
An authenticated user SHALL be able to list all currently open parking
sessions.

#### Scenario: Fetch open sessions
- **WHEN** an authenticated user requests the open session list
- **THEN** the system returns every session with status open, including vehicle,
  operator, and entry time

### Requirement: Unauthenticated check-in is rejected
The system SHALL reject a check-in request from an unauthenticated caller.

#### Scenario: Missing credentials
- **WHEN** an unauthenticated caller attempts to check in a vehicle
- **THEN** the system rejects the request with an unauthorized error

### Requirement: Offline check-in queues instead of failing
When a check-in attempt fails due to a network failure (not a business-rule
rejection), the system SHALL queue it for automatic replay instead of
failing the operator's action.

#### Scenario: Check in while offline
- **WHEN** an authenticated user checks in a known-plate vehicle (with or
  without photos) while the device has no connectivity
- **THEN** the app persists the photos locally, queues the check-in for
  replay, and shows the session with a pending-sync status instead of an
  error

#### Scenario: Queued check-in replays once online
- **WHEN** connectivity is restored after a check-in was queued
- **THEN** the app resubmits the same plate and photos, and the session
  becomes a normal open session once the server confirms it

#### Scenario: Business-rule rejection still fails immediately
- **WHEN** a check-in is attempted for an unknown plate or a vehicle that
  already has an open session, regardless of connectivity
- **THEN** the system rejects it immediately and does NOT queue it for
  replay

### Requirement: Rate locked and shown at check-in
WHILE the lot has dynamic pricing enabled, the system SHALL store on every new open session the rate locked at entry (`pricing_lock`), the check-in screen SHALL show the current rate before the operator confirms, and the entry receipt SHALL show the locked rule when the device is online. A lot with pricing disabled SHALL see no change.

#### Scenario: Locked at entry
- **WHEN** a car enters while a matching rule exists
- **THEN** the session stores its `pricing_lock` and the entry receipt shows the rule name

#### Scenario: Disabled lot unchanged
- **WHEN** a car enters in a lot with pricing disabled
- **THEN** no lock is stored and the receipt has no rate line

#### Scenario: Offline entry receipt
- **WHEN** a check-in is queued offline
- **THEN** the pending receipt says the rate is confirmed when synced and shows no rate

### Requirement: Loyalty progress at check-in
WHILE the lot has the loyalty program enabled and the device is online, the check-in screen SHALL show the progress of the typed plate ("Visit n of N") and a reward badge when a reward is available. The information SHALL be advisory: no check-in SHALL be blocked or delayed by its absence or failure, and a queued offline check-in SHALL be unaffected.

#### Scenario: Chip while typing a known plate
- **WHEN** the operator enters a plate with progress 3 of 5
- **THEN** the screen shows "Visit 4 of 5"

#### Scenario: Failure never blocks
- **WHEN** the status request fails or the device is offline
- **THEN** the chip is hidden or shows a retry and the check-in can be confirmed

### Requirement: Guided photo capture
The check-in form SHALL show a non-blocking guidance banner and angle chips above the evidence photo strip that name the next suggested angle (front-left, front-right, rear-right, rear-left, then a close-up of any damage) and offer an illustration with the capture rules (about 3 m away, whole vehicle in frame, avoid backlight, repeat the same corners at exit). The guidance MUST be UI-only: it MUST NOT make photos mandatory, change the number or size limits of photos, change the upload paths, or change the parameters of the `check_in` RPC.

#### Scenario: Banner names the next angle
- **WHEN** the operator has captured one photo
- **THEN** the banner reads "Next photo: front-right corner" in the app language and the first chip is marked as captured

#### Scenario: Check-in without photos still works
- **WHEN** the operator submits the check-in with no photos
- **THEN** the check-in succeeds exactly as before

#### Scenario: Submission payload unchanged
- **WHEN** the operator submits with three photos
- **THEN** the photos and RPC parameters sent are the same as before this change

