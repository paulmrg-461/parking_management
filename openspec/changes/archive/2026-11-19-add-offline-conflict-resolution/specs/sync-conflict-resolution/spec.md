## ADDED Requirements

### Requirement: Conflicts are detected on replay
WHEN a queued update or delete of a vehicle, tariff, category or settings row is replayed with its base version and the server reports a version conflict, the system SHALL NOT overwrite the server row. The system SHALL handle the conflict by the rules below and SHALL NOT drop the queued change at any point except by an explicit user choice or because the server already holds the same values.

#### Scenario: Stale replay does not overwrite
- **WHEN** an offline tariff edit is replayed after another admin changed the same row
- **THEN** the server row keeps the other admin's values until the user decides

#### Scenario: Another entity is not blocked
- **WHEN** one entry is in conflict and a later entry for a different row is pending
- **THEN** the later entry is still replayed in the same drain

### Requirement: Non-overlapping changes merge automatically
The system SHALL compare the queued patch field by field with the stored base snapshot and the current server row. A field the other writer did not change SHALL be applied without asking. A field whose server value already equals the queued value SHALL be dropped from the patch. WHEN no field conflicts, the system SHALL resend the merged patch on top of the current server version, at most 3 rounds per drain, and SHALL remove the entry once the server holds the result.

#### Scenario: Different fields
- **WHEN** the offline edit changed `color` and another admin changed `brand` of the same vehicle
- **THEN** both changes end up on the server and the user is not asked anything

#### Scenario: Same value
- **WHEN** both writers set a category capacity to the same number
- **THEN** the entry is removed and the cache shows the server row

#### Scenario: Server moves again while merging
- **WHEN** the server version changes between two merge rounds
- **THEN** the system merges again, and after the third round parks the entry for the user

#### Scenario: Money is never guessed
- **WHEN** both writers changed a tariff `amount` to different values
- **THEN** the field is reported as a conflict and not applied

### Requirement: Needs-resolution state
The system SHALL keep an outbox entry whose fields overlap with the server row in a state distinct from retryable and from dead-letter, SHALL NOT replay it automatically, SHALL store the server row it conflicted with, and SHALL expose it in a list separate from dead letters. A persisted conflict entry SHALL also be marked dead-lettered in storage so that an older app build shows it as a dead letter and never replays it blindly.

#### Scenario: Overlapping fields
- **WHEN** both writers changed `amount` of one tariff differently
- **THEN** the entry is in the needs-resolution state with the server row stored, and later drains skip it

#### Scenario: Not a dead letter
- **WHEN** the sync status is read
- **THEN** conflicts appear in `conflicts` and not in `deadLetters`

#### Scenario: Older build safety
- **WHEN** a build that predates this change loads the stored entry
- **THEN** it treats it as a dead letter and does not replay it

### Requirement: User resolves each conflict
WHEN an entry needs resolution the system SHALL let the user choose, for each conflicting field, the queued value or the server value; or keep all queued values; or keep all server values. The system SHALL send only the chosen queued values plus the automatically mergeable ones, based on the server version shown, and SHALL discard the queued change only when the user keeps the server values. WHEN the server changed again before the resend, the entry SHALL return to needs-resolution showing the new server row.

#### Scenario: Per-field choice
- **WHEN** the user picks the queued `amount` and the server `end_time`
- **THEN** only `amount` (plus auto-merged fields) is sent and the cache ends with the server `end_time`

#### Scenario: Keep the server's
- **WHEN** the user keeps the server values
- **THEN** the entry is removed and the local cache shows the server row

#### Scenario: Changed again
- **WHEN** the server version moved while the user was deciding
- **THEN** the entry is back in needs-resolution with the new server row and the dialog says the record changed again

#### Scenario: Resolution fails offline
- **WHEN** the user applies a choice without connectivity
- **THEN** the entry stays queued with the choice applied and replays when online

### Requirement: Delete versus edit
WHEN a queued delete meets a row that was edited by someone else, the system SHALL park it and offer "delete anyway" or "keep the record". WHEN a queued edit meets a row deleted by someone else, the system SHALL park it and offer only "accept the deletion", which removes the row from the local cache. WHEN a queued delete meets a row already deleted, or an edit meets identical values, the system SHALL succeed silently.

#### Scenario: Edited while deleting
- **WHEN** an offline delete is replayed and the row was edited meanwhile
- **THEN** the entry needs resolution with the choices delete anyway or keep the record

#### Scenario: Deleted while editing
- **WHEN** an offline edit is replayed and the row was deleted meanwhile
- **THEN** the entry needs resolution and the only choice is to accept the deletion

#### Scenario: Both deleted
- **WHEN** an offline delete is replayed and the row is already gone
- **THEN** the entry is removed without asking

### Requirement: Check-in and check-out are not versioned
The system SHALL keep replaying queued check-ins and check-outs by their idempotency key, and SHALL keep parking a domain refusal (for example `SessionAlreadyClosedError`, `DuplicateOpenSessionError`) as a visible dead letter. The system SHALL NOT apply row versions to them.

#### Scenario: Retried check-out
- **WHEN** a queued check-out is replayed twice with the same key
- **THEN** the second call returns the stored answer and no conflict arises

#### Scenario: Session closed by someone else
- **WHEN** a queued check-out targets a session already closed with another key
- **THEN** the entry becomes a dead letter with the server message

### Requirement: Online edits use the same rules
WHEN an online edit of one of the four entities is refused because the base version is stale, the system SHALL store the intended change as a needs-resolution entry, report a localized conflict message and refuse further edits of that row with `ConflictPendingError` until the conflict is resolved.

#### Scenario: Online stale edit
- **WHEN** an admin saves a tariff form built from a stale row while online
- **THEN** a conflict entry is stored, the admin sees the conflict message, and the sync badge counts it

#### Scenario: Edit blocked while pending
- **WHEN** a conflict entry exists for a vehicle and the admin edits that vehicle again
- **THEN** the system refuses with `ConflictPendingError`

### Requirement: Sync badge shows conflicts
The sync badge SHALL include conflicts in its count, SHALL show a distinct icon and tooltip when only conflicts are pending (dead letters take precedence), and the details sheet SHALL list conflicts in their own section opening the resolution dialog. The dialog SHALL implement the four UI states (resolving, content, closed when none remain, error with retry), use design tokens, meet the 48 dp touch target and present base, mine and server values per field.

#### Scenario: Count and icon
- **WHEN** one conflict and two pending entries exist
- **THEN** the badge shows 3 and the conflict section lists one tile

#### Scenario: Errors outrank conflicts
- **WHEN** a dead letter and a conflict exist
- **THEN** the badge shows the error icon

#### Scenario: Nothing to do
- **WHEN** the outbox is empty
- **THEN** the badge is hidden

#### Scenario: Accessibility
- **WHEN** the dialog is rendered
- **THEN** it passes the tap-target, label and text-contrast guidelines

### Requirement: Authorization and privacy are unchanged
The system SHALL keep every authorization decision in row level security, SHALL never expose a server row the user cannot read in a conflict, and SHALL report a refused write with an unchanged version as `PermissionDeniedError` rather than as a conflict.

#### Scenario: Non-admin edit
- **WHEN** an operator's queued tariff edit is replayed
- **THEN** it fails as a permission error (dead letter) and not as a conflict

#### Scenario: Hidden row
- **WHEN** the row belongs to another lot
- **THEN** the replay reports the same refusal as today and reveals no row data
