## ADDED Requirements

### Requirement: Overstay alerts
The system SHALL notify admins once per day for each open session that exceeds
the configured `overstay_hours`.

#### Scenario: Vehicle exceeds the threshold
- **WHEN** a session has been open longer than `overstay_hours`
- **THEN** each active admin receives one overstay notification for that day
