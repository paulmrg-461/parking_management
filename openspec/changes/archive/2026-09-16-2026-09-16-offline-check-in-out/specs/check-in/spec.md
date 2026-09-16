## ADDED Requirements

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
