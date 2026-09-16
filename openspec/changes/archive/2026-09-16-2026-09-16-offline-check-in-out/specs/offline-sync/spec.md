## ADDED Requirements

### Requirement: Outbox replays queued check-ins and check-outs
The sync outbox SHALL support queuing and replaying check-in creates and
check-out closes, in addition to the existing vehicle/tariff/category
update/delete entries.

#### Scenario: One stuck entry does not block another
- **WHEN** a queued check-in and a queued check-out are both pending and
  one keeps failing with a network failure during a flush
- **THEN** the other entry is still replayed in the same flush pass

#### Scenario: Successful check-in replay cleans up local photo storage
- **WHEN** a queued check-in is successfully replayed
- **THEN** the app deletes the photos it had persisted locally for that
  queued entry
