## MODIFIED Requirements

### Requirement: Monthly passes can renew automatically
The system SHALL create a linked new pass for the same duration and amount when
an auto-renewing pass expires, without duplicating a prior renewal, including a
renewal created earlier by an online payment. A pass that has ended and already
has a linked renewal SHALL be deactivated.

#### Scenario: Expiry renews once
- **WHEN** the renewal job runs for an expired auto-renew pass
- **THEN** one new pass starts the next day and further runs do nothing

#### Scenario: Manual pass reminder
- **WHEN** a non-auto-renew pass expires in three days
- **THEN** admins receive the expiry reminder

#### Scenario: Already renewed online
- **WHEN** the renewal job runs for an expired auto-renew pass whose customer already renewed it through a payment link
- **THEN** no second pass is created and the ended pass is deactivated

#### Scenario: Pass still valid is never deactivated early
- **WHEN** a pass already has a renewal but its end date is today or later
- **THEN** it stays active until its end date has passed
