## ADDED Requirements

### Requirement: Camera direction and per-lot LPR settings
The system SHALL store per lot the LPR mode (`assist` or `auto`, default `assist`), the minimum confidence (default 0.80), the automatic confidence (default 0.92, never below the minimum), the minimum votes (1 to 10, default 3), the vote window (2 to 60 s, default 8), the cooldown (10 to 3600 s, default 120), the default category for unknown plates and the system operator, and SHALL store for each camera device whether it watches the `entry` or the `exit`. Only admins of the lot SHALL change them, through `set_lpr_settings` and `set_lpr_camera_direction`. IF a value is outside its range, THEN the system SHALL raise `InvalidDataError`. IF the mode is set to `auto` and no active system operator that belongs to the lot is configured, THEN the system SHALL raise `LprSystemOperatorRequiredError`. IF the device is not a camera, THEN `set_lpr_camera_direction` SHALL raise `InvalidDeviceKindError`.

#### Scenario: Admin switches to auto
- **WHEN** an admin with a valid system operator and default category calls `set_lpr_settings(p_mode => 'auto')`
- **THEN** the lot's mode is `auto` and the change is recorded in `audit_log`

#### Scenario: Auto without a system operator
- **WHEN** an admin sets mode `auto` on a lot with no system operator
- **THEN** the system raises `LprSystemOperatorRequiredError` and the mode stays `assist`

#### Scenario: Automatic confidence below minimum
- **WHEN** an admin sets `p_auto_confidence` to 0.70 while the minimum is 0.80
- **THEN** the system raises `InvalidDataError`

#### Scenario: Operator cannot change settings
- **WHEN** an operator calls `set_lpr_settings(p_mode => 'auto')`
- **THEN** the system raises `AdminRequiredError` and the settings are unchanged

#### Scenario: Another lot keeps its own mode
- **WHEN** lot 1 is set to `auto`
- **THEN** lot 2 still reports `assist`

### Requirement: Plate reads from a camera device
The gateway SHALL accept plate reads only from authenticated, enabled devices of kind `camera` at `POST /v1/lpr/reads`, with a unique `client_ref` that equals the `Idempotency-Key` header, a plate, a confidence greater than 0 and at most 1, and the capture time. The system SHALL apply the SQL plate normalization (uppercase, whitespace removed) and SHALL reject any plate that does not match `^[A-Z0-9]{4,10}$` with `InvalidPlateError` without altering it. IF the capture time is more than 5 minutes ahead of the server, THEN the system SHALL raise `InvalidReadTimeError`. IF it is older than 15 minutes, THEN the system SHALL store the read with outcome `stale` and SHALL NOT use it for a decision. IF the camera has no direction, THEN the system SHALL raise `LprDirectionNotSetError`. A repeated `client_ref` from the same device SHALL return the original outcome and SHALL NOT create another read or event.

#### Scenario: Read is recorded
- **WHEN** a camera posts a valid read and fewer votes than `min_votes` exist
- **THEN** the gateway answers 200 with outcome `recorded` and no event

#### Scenario: Lowercase and spaces are normalized
- **WHEN** the plate arrives as `abc 123`
- **THEN** the stored plate is `ABC123`

#### Scenario: Plate with a hyphen is refused
- **WHEN** the plate arrives as `ABC-123`
- **THEN** the system raises `InvalidPlateError` and stores nothing

#### Scenario: Retried read is idempotent
- **WHEN** the same `client_ref` is posted twice
- **THEN** the second answer has outcome `replayed` and the number of reads and events is unchanged

#### Scenario: Stale read is never decided
- **WHEN** a read captured 20 minutes ago arrives
- **THEN** outcome is `stale` and no event is created

#### Scenario: Non-camera device
- **WHEN** a device of kind `barrier` posts to `/v1/lpr/reads`
- **THEN** the gateway answers 403 `DeviceKindNotAllowedError`

#### Scenario: Read below the minimum confidence
- **WHEN** a read has confidence 0.60 and the minimum is 0.80
- **THEN** outcome is `ignored_low_confidence` and it does not count as a vote

### Requirement: Debounce and voting
The system SHALL decide only when at least `min_votes` undecided reads of the same camera and plate, each with confidence at or above the minimum, fall within `vote_window_seconds` of the newest read, and SHALL attach those reads to the resulting event so they are never counted again. WHILE an event for the same lot, direction and plate is younger than `cooldown_seconds`, the system SHALL NOT create another event for it and SHALL mark new reads `debounced`. Two reads of different plates SHALL NOT vote for each other.

#### Scenario: Third read decides
- **WHEN** three reads of `ABC123` with confidence above the minimum arrive within 8 seconds
- **THEN** the third answer has outcome `decided` and exactly one event exists

#### Scenario: Reads outside the window do not combine
- **WHEN** two reads arrive 30 seconds apart and `min_votes` is 3
- **THEN** no event is created

#### Scenario: Car idling in front of the camera
- **WHEN** an event for `ABC123` exists and more reads of `ABC123` arrive within the cooldown
- **THEN** they are `debounced` and no second event is created

#### Scenario: Different plates do not mix
- **WHEN** reads alternate between `ABC123` and `ABC128`
- **THEN** neither reaches `min_votes` unless it has enough reads on its own

### Requirement: Entry decisions
WHEN a decided entry event is created, the system SHALL apply the first matching rule: a blacklisted vehicle creates a `blocked` event with reason `blacklisted`; an open session of the vehicle creates a `pending` event with reason `duplicate_session`; mode `assist` creates a `pending` event with reason `assist_mode`; mode `auto` with a mean confidence below the automatic confidence creates `pending` with reason `low_confidence`; mode `auto` for an unknown plate without a default category creates `pending` with reason `unknown_plate`; mode `auto` without a usable system operator creates `pending` with reason `no_system_operator`; otherwise the system SHALL check the vehicle in with `check_in` on behalf of the system operator, attributing the session to that user, and create a `done` event that references the session. IF `check_in` raises `ParkingFullError` or `CategoryFullError`, THEN the event SHALL be `pending` with reason `lot_full`; IF it raises any other error, THEN the event SHALL be `pending` with reason `error` and the error name in `detail`. A blacklisted vehicle SHALL NEVER be checked in automatically.

#### Scenario: Assist mode asks the operator
- **WHEN** a known, non-blacklisted vehicle is decided at an entry camera in `assist` mode
- **THEN** the event is `pending` with reason `assist_mode`, no session exists and every active member of the lot gets a `lpr_pending` notification

#### Scenario: Auto mode checks in
- **WHEN** mode is `auto`, the mean confidence is 0.95 and the vehicle is known and allowed
- **THEN** an open session exists with `operator_id` equal to the system operator and the event is `done` with that session

#### Scenario: Unknown plate follows the auto-register rule
- **WHEN** mode is `auto`, the plate has no vehicle and the lot has a default category
- **THEN** a vehicle is created by `check_in` with that category and a session is opened

#### Scenario: Unknown plate without a default category
- **WHEN** mode is `auto`, the plate has no vehicle and no default category is set
- **THEN** the event is `pending` with reason `unknown_plate` and no vehicle is created

#### Scenario: Blacklisted vehicle never auto-enters
- **WHEN** mode is `auto` and the vehicle has `is_blacklisted = true`
- **THEN** the event is `blocked` with reason `blacklisted`, no session is created and a `lpr_blacklisted` notification is sent

#### Scenario: Lot full
- **WHEN** `check_in` raises `ParkingFullError` during an automatic entry
- **THEN** the event is `pending` with reason `lot_full` and no session exists

#### Scenario: Vehicle already inside
- **WHEN** a vehicle with an open session is read at the entry camera
- **THEN** the event is `pending` with reason `duplicate_session` and the existing session is untouched

#### Scenario: Low confidence in auto mode
- **WHEN** mode is `auto` and the mean confidence is 0.85 with an automatic confidence of 0.92
- **THEN** the event is `pending` with reason `low_confidence`

#### Scenario: System operator deactivated
- **WHEN** mode is `auto` and the system operator user is inactive
- **THEN** the event is `pending` with reason `no_system_operator`

### Requirement: Exit never closes a session
WHEN a decided exit event is created, the system SHALL NOT modify, close or charge any session. A blacklisted vehicle SHALL create a `blocked` event and a `lpr_blacklisted` notification. A vehicle with an open session in the lot SHALL create a `pending` event with reason `exit_unpaid` that references the session and a `lpr_exit` notification. A vehicle with no open session but a session of the lot closed within `exit_paid_window_minutes` SHALL create a `done` event with reason `exit_paid`. Otherwise the system SHALL create a `pending` event with reason `no_open_session`. The event SHALL record whether the vehicle has an active monthly pass in the lot. WHEN the referenced session is later closed through the normal check-out, the system SHALL mark an `exit_unpaid` event `confirmed`.

#### Scenario: Unpaid exit alerts the desk
- **WHEN** a vehicle with an open session is read at the exit camera in either mode
- **THEN** the event is `pending` with reason `exit_unpaid`, the session is still `open` and each member of the lot gets a `lpr_exit` notification

#### Scenario: Paid exit
- **WHEN** the vehicle's session was closed 3 minutes ago and it is read at the exit camera
- **THEN** the event is `done` with reason `exit_paid` and no notification is sent

#### Scenario: Exit without a session
- **WHEN** an unknown vehicle is read at the exit camera
- **THEN** the event is `pending` with reason `no_open_session`

#### Scenario: Event is closed by the real check-out
- **WHEN** an operator completes the check-out of the referenced session and `expire_lpr_events` runs
- **THEN** the event status is `confirmed`

#### Scenario: Pass holder is flagged
- **WHEN** a vehicle with an active monthly pass is decided
- **THEN** the event has `has_pass = true`

### Requirement: Operator confirmation of entries
The system SHALL let any member of the lot list events with `list_lpr_events`, confirm a pending entry with `confirm_lpr_entry`, and dismiss a pending or blocked event with `dismiss_lpr_event`. Confirming SHALL run `check_in` as the signed-in operator, MAY correct the plate (normalized and validated again) and MAY choose the category for an unknown vehicle, SHALL attach the snapshot as evidence of the session and SHALL mark the event `confirmed` with the operator and time. Confirming twice SHALL return the same session. IF the event is not pending, THEN the system SHALL raise `LprEventResolvedError`; IF it is an exit event, THEN `LprEventKindError`; IF it belongs to another lot or does not exist, THEN `LprEventNotFoundError`.

#### Scenario: Operator corrects a misread plate
- **WHEN** an event for `ABC128` is pending and the operator confirms with plate `ABC123`
- **THEN** a session is opened for `ABC123`, the event is `confirmed` and `resolved_by` is the operator

#### Scenario: Double tap
- **WHEN** the operator confirms the same event twice
- **THEN** both calls return the same session id and only one session exists

#### Scenario: Event of another lot
- **WHEN** an operator of lot 1 confirms an event of lot 2
- **THEN** the system raises `LprEventNotFoundError`

#### Scenario: Already handled
- **WHEN** an operator confirms an event that is `dismissed`
- **THEN** the system raises `LprEventResolvedError`

#### Scenario: Confirming an exit event
- **WHEN** an operator calls `confirm_lpr_entry` for an exit event
- **THEN** the system raises `LprEventKindError`

#### Scenario: Pending items expire
- **WHEN** a pending event is older than the lot's `pending_expire_minutes` and `expire_lpr_events` runs
- **THEN** its status is `expired`

### Requirement: Snapshot evidence
WHEN the gateway receives `PUT /v1/lpr/events/:id/snapshot` from a camera with a JPEG body of at most 262144 bytes that starts with the JPEG signature, it SHALL store the image in the `evidence` bucket at `lpr/<lot_id>/<device_id>/<event_id>.jpg` and attach it to the event; IF the event already has a session, THEN the system SHALL also add the image to that session's evidence photos. A second upload for the same event SHALL answer 409 `SnapshotAlreadyAttachedError`. A camera SHALL NOT attach a snapshot to an event of another device or lot. Members of the event's lot SHALL be able to download the snapshot while the event exists, and members of other lots SHALL NOT.

#### Scenario: Snapshot attached to an automatic session
- **WHEN** a camera uploads the snapshot of a `done` entry event
- **THEN** the event has `snapshot_path` and the session's evidence list includes that photo

#### Scenario: Not a JPEG
- **WHEN** the body does not start with `FF D8 FF`
- **THEN** the gateway answers 400 `InvalidDataError` and nothing is stored

#### Scenario: Too large
- **WHEN** the body exceeds 262144 bytes
- **THEN** the gateway answers 413 `PayloadTooLargeError`

#### Scenario: Event of another device
- **WHEN** camera A uploads a snapshot for an event created by camera B
- **THEN** the gateway answers 404 `LprEventNotFoundError`

#### Scenario: Lot isolation on download
- **WHEN** a member of lot 2 only requests the snapshot of a lot 1 event
- **THEN** Storage denies the download

### Requirement: LPR alerts reach the desk
The system SHALL notify every active member of the lot with type `lpr_pending` when an entry needs confirmation, `lpr_exit` when a vehicle leaves with an open session, and `lpr_blacklisted` when a blacklisted vehicle is read, without duplicating a notification for the same event. Tapping them SHALL open `/gate`.

#### Scenario: One notification per event and user
- **WHEN** an event is decided and the notification trigger code runs twice for it
- **THEN** each member has exactly one notification for that event

#### Scenario: Other lots are not notified
- **WHEN** an event is created in lot 1
- **THEN** a user who is only a member of lot 2 receives nothing

### Requirement: Operator gate screen
The app SHALL provide `/gate`, available to operators and admins, that lists pending and blocked events with snapshot, plate, confidence, reason (text and icon) and age, lets the operator confirm (with an editable plate and, for unknown vehicles, a category), dismiss, or open the check-out for an exit event, and refreshes when an LPR notification arrives and every 10 seconds while open. It SHALL render four states (loading skeleton, list, empty with a call to action, error with retry). Confirming SHALL be unavailable offline and SHALL NOT be queued. `/gate-settings` SHALL be reachable by admins only and SHALL ask for explicit confirmation before enabling automatic mode.

#### Scenario: Exit card opens the check-out
- **WHEN** the operator taps "Open check-out" on an `exit_unpaid` card for `ABC123`
- **THEN** the app navigates to `/check-out?scan=ABC123`

#### Scenario: Empty inbox
- **WHEN** no events are pending
- **THEN** the empty state with its call to action is shown

#### Scenario: Operator cannot open settings
- **WHEN** an operator navigates to `/gate-settings`
- **THEN** the router redirects to the home route

#### Scenario: Confirmation offline
- **WHEN** the operator taps Confirm without connectivity
- **THEN** a message is shown and no request or outbox entry is created

#### Scenario: Auto mode needs confirmation
- **WHEN** an admin selects automatic mode
- **THEN** a dialog with the spoofing warning appears and the mode only changes after the admin accepts

### Requirement: Edge service resilience
The reference edge service SHALL send every read with a `client_ref` generated before the first attempt and reused on every retry, SHALL persist unsent reads in a local queue and send them in order, SHALL discard queued reads older than 15 minutes, SHALL reconnect to the RTSP source with exponential backoff capped at 30 seconds, SHALL keep sending heartbeats while the camera is down, SHALL derive its sequence from a persisted boot counter so a restart never sends a sequence lower than before, SHALL send only characters `A-Z0-9` in plates and SHALL refuse to start when a model file does not match its configured SHA-256.

#### Scenario: Network loss then recovery
- **WHEN** the gateway is unreachable for 2 minutes while reads are produced
- **THEN** the reads are sent in order after recovery, each with its original `client_ref`

#### Scenario: Restart between enqueue and send
- **WHEN** the process is killed after a read was queued and before it was sent
- **THEN** after restart the read is sent once with the same `client_ref` and a greater sequence than any earlier request

#### Scenario: RTSP source restarts
- **WHEN** the RTSP server is stopped and started again
- **THEN** the service reconnects within the backoff schedule and heartbeats report the camera as down in between

#### Scenario: Expired queue entries
- **WHEN** a queued read is 16 minutes old
- **THEN** it is discarded and counted in the heartbeat

#### Scenario: Tampered model
- **WHEN** an engine file's hash differs from the configured SHA-256
- **THEN** the service exits with a configuration error and does not send reads
