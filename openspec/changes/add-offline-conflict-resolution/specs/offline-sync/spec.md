## ADDED Requirements

### Requirement: Queued updates carry their base version
The system SHALL store, with each queued update or delete of a vehicle, tariff, category or settings row, the row version and the field snapshot it was edited from, SHALL send that version as the write's filter on replay, and SHALL treat an entry without a base version (written by an older build, or a cache row of unknown version) as a legacy last-write-wins entry that is replayed without a version filter and can never become a conflict.

#### Scenario: Base stored
- **WHEN** an admin edits a cached tariff offline
- **THEN** the queued entry holds the cached version and snapshot

#### Scenario: Legacy entry
- **WHEN** an entry written before this change is replayed
- **THEN** it is sent without a version filter and succeeds as before

#### Scenario: Unknown version
- **WHEN** the cached row has version 0 (cached before the upgrade)
- **THEN** the entry stores no base version

### Requirement: Consecutive edits of one row coalesce
WHEN an update or delete is queued for a row that already has a pending entry, the system SHALL merge the new patch into that entry (new values win), keep the original base version and snapshot, and SHALL NOT merge into conflict or dead-letter entries or into check-in and check-out entries. WHEN a replay succeeds while a newer edit was merged into the same entry, the system SHALL keep the entry, rebased on the new version, instead of removing it.

#### Scenario: Two offline edits
- **WHEN** an admin edits a tariff's amount and then its end time offline
- **THEN** one entry with both fields is queued and it does not conflict with itself on replay

#### Scenario: Edit during replay
- **WHEN** an edit is queued while the previous entry for that row is being sent
- **THEN** the new edit survives the removal of the sent one

#### Scenario: Delete after edit
- **WHEN** a delete is queued for a row with a pending update
- **THEN** the entry becomes a delete keeping the original base

### Requirement: Settings queue only changed fields
The system SHALL queue, for an offline settings save, only the fields whose values differ from the cached settings, plus the lot id, and SHALL send nothing when no field differs.

#### Scenario: One field changed
- **WHEN** an admin changes only the phone offline
- **THEN** the queued payload contains `phone` and `lot_id` only

#### Scenario: No change
- **WHEN** the admin saves without changes
- **THEN** no request is sent and nothing is queued

### Requirement: Outbox format is backward compatible
The system SHALL read every persisted outbox entry written by earlier builds without migration, defaulting the new fields (`baseVersion`, `baseSnapshotJson`, `needsResolution`, `conflictKind`, `serverJson`, `conflictAt`) to absent, and SHALL keep skipping corrupt entries without blocking the queue.

#### Scenario: Old JSON
- **WHEN** the box contains an entry with only the original keys
- **THEN** it loads as a pending legacy entry

#### Scenario: Corrupt entry
- **WHEN** an entry cannot be decoded
- **THEN** it is skipped and the others still replay

### Requirement: Category patches replay completely
The system SHALL send the whole queued category patch (name and capacity) on replay.

#### Scenario: Name and capacity together
- **WHEN** a queued category patch holds both `name` and `capacity`
- **THEN** both are applied on the server
