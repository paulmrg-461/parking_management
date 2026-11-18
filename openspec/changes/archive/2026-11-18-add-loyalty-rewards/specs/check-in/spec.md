## ADDED Requirements

### Requirement: Loyalty progress at check-in
WHILE the lot has the loyalty program enabled and the device is online, the check-in screen SHALL show the progress of the typed plate ("Visit n of N") and a reward badge when a reward is available. The information SHALL be advisory: no check-in SHALL be blocked or delayed by its absence or failure, and a queued offline check-in SHALL be unaffected.

#### Scenario: Chip while typing a known plate
- **WHEN** the operator enters a plate with progress 3 of 5
- **THEN** the screen shows "Visit 4 of 5"

#### Scenario: Failure never blocks
- **WHEN** the status request fails or the device is offline
- **THEN** the chip is hidden or shows a retry and the check-in can be confirmed
