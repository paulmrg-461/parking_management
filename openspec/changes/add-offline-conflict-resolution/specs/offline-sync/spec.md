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

## MODIFIED Requirements

### Requirement: Queue an update or delete while offline
When `update` or `delete` on a vehicle, tariff, category or a lot setting
fails with a network failure, the system SHALL apply the change to the local
cache and queue it for later replay instead of failing the operation. The
queued mutation SHALL carry the row version it was edited from and a snapshot
of the fields it changed, so a replay can prove the base it was written
against.

#### Scenario: Update a vehicle while offline
- **WHEN** an admin updates a vehicle's color while the device has no
  connectivity
- **THEN** the system updates the local cache with the merged result, queues
  the mutation with the row's base version and the changed fields, and returns
  the merged vehicle without raising an error

#### Scenario: Update a lot setting while offline
- **WHEN** an admin changes the evidence retention while offline
- **THEN** only the changed settings fields are queued, with the settings row's
  base version

### Requirement: Replay queued mutations on reconnect
The system SHALL replay every queued mutation against the backend once
connectivity is restored, sending the base version as the write filter and
removing each one from the queue only after it succeeds. WHEN the row changed
on the server since that base, THE SYSTEM SHALL NOT overwrite it: a
non-overlapping edit is merged and replayed automatically, an overlapping one
moves the mutation to the needs-resolution state and notifies the operator
through the sync badge.

#### Scenario: Connectivity restored
- **WHEN** the device regains connectivity after queuing an update
- **THEN** the system sends the queued update with its version filter and
  removes it from the queue on success

#### Scenario: Stale base with a disjoint change
- **WHEN** another admin edited a different field of the same row while this
  device was offline
- **THEN** the system merges the two edits, replays the mutation and clears it

#### Scenario: Stale base with an overlapping change
- **WHEN** another admin edited the same field with a different value
- **THEN** the mutation is kept in the needs-resolution state with both values
  and nothing is written until the operator chooses

### Requirement: Scope limited to update/delete on reference data
Only `update` and `delete` mutations on vehicles, tariffs, categories and lot
settings SHALL be queued. Check-in, check-out, monthly passes and every
`create` mutation SHALL remain unaffected (remote-only, unchanged failure
behavior). A direct table write that does not send the expected version filter
SHALL be refused once the lot turns on `row_version_required`.

#### Scenario: Check-out stays remote-only
- **WHEN** an operator attempts to check out a vehicle while offline
- **THEN** the system rejects the request immediately (no queuing), since
  `exit_time` must be captured at the moment of closing

#### Scenario: Vehicle creation stays remote-only
- **WHEN** an admin attempts to create a new vehicle while offline
- **THEN** the system rejects the request immediately (no queuing), since a
  create requires a server-assigned id

#### Scenario: Unversioned write after the policy is on
- **WHEN** a client that does not send `version=eq.<n>` patches a tariff and the
  lot has `row_version_required = true`
- **THEN** the database refuses the write (`VersionRequiredError`) instead of
  applying a silent overwrite
