## ADDED Requirements

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
