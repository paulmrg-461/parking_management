## ADDED Requirements

### Requirement: Monthly passes can renew automatically
The system SHALL create a linked new pass for the same duration and amount when
an auto-renewing pass expires, without duplicating a prior renewal.

#### Scenario: Expiry renews once
- **WHEN** the renewal job runs for an expired auto-renew pass
- **THEN** one new pass starts the next day and further runs do nothing

#### Scenario: Manual pass reminder
- **WHEN** a non-auto-renew pass expires in three days
- **THEN** admins receive the expiry reminder
