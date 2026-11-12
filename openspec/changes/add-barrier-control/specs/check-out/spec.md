## ADDED Requirements

### Requirement: Paid exit may open the exit barrier
WHEN a session of a lot is closed through check-out, the system SHALL request an open command for the exit barrier that handled that vehicle, provided the barrier's configuration allows it, and the closing of the session SHALL NOT fail or be delayed if the command cannot be issued. The system SHALL NOT request an open command for a session that is not closed.

#### Scenario: Desk payment opens the barrier of the waiting car
- **WHEN** an exit camera produced an `exit_unpaid` event for a session 40 seconds ago and the operator then closes that session
- **THEN** a command with source `paid_exit` is queued for the exit barrier paired with that camera

#### Scenario: Open session never opens the barrier
- **WHEN** a session is still open
- **THEN** no `paid_exit` command exists for it

#### Scenario: Barrier problem does not block payment
- **WHEN** the paired barrier is disabled and an operator closes the session
- **THEN** the check-out succeeds and no command is created
