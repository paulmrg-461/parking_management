## ADDED Requirements

### Requirement: Barrier configuration
The system SHALL store for each device of kind `barrier` its direction (`entry` or `exit`), an optional paired camera device of the same lot, the rule for opening on check-in and on paid exit (`never`, `lpr_only` or `always`, default `lpr_only`), whether to open for recognised monthly-pass holders at an entry (default off), the pulse length, the maximum open time, the close delay after passing, the maximum safety reversals and the command lifetime (default 30 seconds, 10 to 120). Only admins of the lot SHALL change it, through `set_barrier_config`. IF a value is outside its range, THEN the system SHALL raise `InvalidDataError`. IF the device is not a barrier of the lot, or the paired device is not a camera of the same lot, THEN the system SHALL raise `InvalidDeviceKindError`.

#### Scenario: Admin pairs a camera
- **WHEN** an admin calls `set_barrier_config(p_device_id => 7, p_camera_device_id => 3)` for a barrier 7 and a camera 3 of the same lot
- **THEN** `list_barriers()` shows the pairing for barrier 7

#### Scenario: Camera of another lot
- **WHEN** an admin pairs a barrier of lot 1 with a camera of lot 2
- **THEN** the system raises `InvalidDeviceKindError` and the configuration is unchanged

#### Scenario: Out of range timing
- **WHEN** an admin sets `p_command_ttl_seconds` to 5
- **THEN** the system raises `InvalidDataError`

#### Scenario: Operator cannot configure
- **WHEN** an operator calls `set_barrier_config`
- **THEN** the system raises `AdminRequiredError`

### Requirement: Signed, single-use, short-lived open commands
The system SHALL deliver an open command to a barrier only as a message signed with Ed25519 over the canonical text `parking-barrier-v1|<command id>|<device id>|open|<issued_at>|<expires_at>|<nonce>|<hold_ms>|<max_open_s>`, using a private key that exists only in the gateway's environment and never in the database. A command SHALL expire after the lot's command lifetime, SHALL be delivered at most 3 times at least 5 seconds apart, and SHALL NOT be delivered once executed, rejected or expired. IF the signing key is not configured, THEN the gateway SHALL answer `503 GatewayUnavailableError` to the command poll and SHALL deliver nothing. The system SHALL deliver a command only to the device it is addressed to.

#### Scenario: Command is delivered signed
- **WHEN** a queued command exists and its barrier polls `GET /v1/barrier/commands/next`
- **THEN** the gateway answers 200 with the command and a signature that verifies against the public key for the canonical text

#### Scenario: Expired command is not delivered
- **WHEN** a queued command is older than its lifetime
- **THEN** the poll answers 204 and `expire_barrier_commands()` marks it `expired`

#### Scenario: Another barrier does not receive it
- **WHEN** a command is addressed to barrier 7 and barrier 8 polls
- **THEN** barrier 8 receives no command

#### Scenario: No signing key
- **WHEN** `BARRIER_COMMAND_SIGNING_KEY` is not set and a barrier polls
- **THEN** the gateway answers 503 and no command changes status

#### Scenario: Executed command is never redelivered
- **WHEN** a barrier acknowledged a command as opened and polls again
- **THEN** the same command is not returned

#### Scenario: Bad signature or changed field is rejected by the device
- **WHEN** the device receives a command whose `hold_ms` differs from the signed value
- **THEN** it does not actuate any relay and acknowledges `refused` with reason `bad_signature`

### Requirement: Barrier firmware accepts nothing else
The barrier firmware SHALL actuate its open output only for a command that has a valid signature, is addressed to its device id, has not expired by the gateway-synchronised clock, has an id not among the last 16 executed, and has an `issued_at` greater than the last executed one persisted in non-volatile memory. The firmware SHALL expose no local input, network service, wireless access point or console that can cause an opening, and SHALL acknowledge every refused command with its reason. WHILE the device has no valid command, all relay outputs SHALL be inactive. The firmware SHALL NOT keep an offline list that authorises openings.

#### Scenario: Expired command
- **WHEN** the device receives a command 40 seconds after its `issued_at` with a 30-second lifetime
- **THEN** no relay is actuated and the ack says `refused` with reason `expired`

#### Scenario: Replayed command after a reboot
- **WHEN** a command already executed is delivered again after the device restarted
- **THEN** the device refuses it with reason `replayed`

#### Scenario: Command for another device
- **WHEN** a correctly signed command carries another device id
- **THEN** the device refuses it with reason `wrong_device`

#### Scenario: Network down
- **WHEN** the device cannot reach the gateway
- **THEN** all relay outputs stay inactive and the barrier is not opened by the device

#### Scenario: Power-up does not open
- **WHEN** the device boots
- **THEN** relay outputs remain inactive for at least 500 ms before the state machine starts and no pulse is produced

### Requirement: Gate cycle, safety inputs and anti-tailgating
WHEN the firmware executes a valid command it SHALL open, keep the arm open while the loop or the beam input is active, and close only after a vehicle has passed (loop active then clear) and the close delay elapsed, or after the signed maximum open time when no vehicle entered. IF the loop or the beam becomes active while closing, THEN the firmware SHALL drive the open output again; IF this happens more than the configured maximum reversals for one command, THEN the firmware SHALL leave the arm open, enter a fault state and report an `obstruction` event. A second vehicle that enters the loop after the first SHALL keep the arm open for safety but SHALL NOT count as authorised and SHALL be reported as `loop_retrigger`. The firmware SHALL NOT be presented as the safety system of the barrier.

#### Scenario: Normal passage
- **WHEN** a command is executed, a vehicle activates and then clears the loop, and the close delay elapses
- **THEN** the arm opens, stays open during the passage and closes after the delay

#### Scenario: No vehicle arrives
- **WHEN** a command is executed and the loop never activates
- **THEN** the arm closes after the signed maximum open time

#### Scenario: Obstruction while closing
- **WHEN** the loop becomes active while the arm is closing
- **THEN** the firmware drives the open output again and counts one reversal

#### Scenario: Too many reversals
- **WHEN** reversals exceed the maximum for one command
- **THEN** the firmware leaves the arm open, enters the fault state and reports `obstruction`

#### Scenario: Tailgater
- **WHEN** a second vehicle activates the loop during the close delay
- **THEN** the arm stays open, a `loop_retrigger` event is reported and no new opening is authorised

### Requirement: Opening follows system facts
The system SHALL issue an open command only from these sources: (1) a check-in produced from a recognised plate (`checkin`), for the barrier paired with the reading camera, or for the single enabled entry barrier of the lot when its rule is `always`; (2) the closing of a session through check-out (`paid_exit`), for the exit barrier paired with the camera that read the waiting vehicle within the previous 15 minutes, or for the single enabled exit barrier when its rule is `always`, and an exit event with reason `exit_paid`; (3) a recognised vehicle with an active monthly pass at an entry whose barrier has the option enabled, with mean confidence of at least 0.95 and neither blocked nor already inside (`pass_recognised`); (4) an operator's manual request (`manual`); (5) the optional online-payment hook (`online_payment`). The system SHALL NOT issue a command for a session that is open at an exit, for a blacklisted vehicle, or for a pass holder at an exit with an open session. Failure to issue a command SHALL NOT fail or delay the check-in or check-out that triggered it. A repeated trigger for the same device, source and session or event SHALL return the existing command.

#### Scenario: LPR check-in opens the entry barrier
- **WHEN** an LPR entry event becomes `done` and its camera is paired with an entry barrier whose rule is `lpr_only`
- **THEN** one `checkin` command is queued for that barrier

#### Scenario: Desk payment opens the waiting car's barrier
- **WHEN** an exit camera reported `exit_unpaid` for a session and the operator closes that session within 15 minutes
- **THEN** one `paid_exit` command is queued for the barrier paired with that camera

#### Scenario: Exit already paid
- **WHEN** the exit camera reads a vehicle whose session was closed 3 minutes ago
- **THEN** one `paid_exit` command is queued for the paired barrier

#### Scenario: Unpaid exit never opens
- **WHEN** a vehicle with an open session is read at the exit camera
- **THEN** no command is created

#### Scenario: Blacklisted vehicle
- **WHEN** a blacklisted vehicle is read at an entry
- **THEN** no command is created

#### Scenario: Pass option off by default
- **WHEN** a pass holder is recognised at an entry whose barrier has `open_for_pass_entry = false`
- **THEN** no command is created

#### Scenario: Pass holder with enough confidence
- **WHEN** the option is on, the mean confidence is 0.97 and the vehicle has no open session
- **THEN** one `pass_recognised` command is queued

#### Scenario: Barrier problem does not block the business operation
- **WHEN** issuing the command raises an error inside the check-out transaction
- **THEN** the check-out still commits and a warning is logged

#### Scenario: Trigger is idempotent
- **WHEN** the same event fires the trigger twice
- **THEN** exactly one command exists for it

#### Scenario: Barrier offline when needed
- **WHEN** the paired barrier has not been seen for longer than the offline threshold
- **THEN** the command is recorded as `expired` with error `barrier_unavailable` and members of the lot receive a `barrier_command_failed` notification

### Requirement: Manual opening is reasoned, audited and limited
The system SHALL let any member of the lot open a barrier of that lot through `request_manual_barrier_open(p_device_id, p_reason)` only with a reason of 3 to 200 characters after trimming, and SHALL store the operator, the reason and the time in the command. IF the barrier is not online, THEN the system SHALL raise `BarrierOfflineError`; IF another command is queued or delivered for it, THEN `BarrierBusyError`; IF the operator already made 10 manual openings in the last hour, THEN `BarrierRateLimitedError`; IF the reason is missing or too short or long, THEN `BarrierReasonRequiredError`. The system SHALL keep commands for at least 365 days. The app SHALL require connectivity for this action and SHALL NOT queue it.

#### Scenario: Operator opens with a reason
- **WHEN** an operator calls `request_manual_barrier_open(7, 'Cliente sin ticket')` and barrier 7 is online
- **THEN** a `manual` command exists with the operator and reason, and every active admin of the lot receives a `barrier_manual_open` notification

#### Scenario: Missing reason
- **WHEN** the reason is empty or two characters long
- **THEN** the system raises `BarrierReasonRequiredError` and creates nothing

#### Scenario: Barrier busy
- **WHEN** a command is queued for the barrier and another manual open is requested
- **THEN** the system raises `BarrierBusyError`

#### Scenario: Rate limit
- **WHEN** an operator requests an eleventh manual opening within an hour
- **THEN** the system raises `BarrierRateLimitedError`

#### Scenario: Barrier of another lot
- **WHEN** an operator of lot 1 requests an opening of a barrier of lot 2
- **THEN** the system raises `DeviceNotFoundError`

#### Scenario: Offline barrier
- **WHEN** the barrier's last request is older than the offline threshold
- **THEN** the system raises `BarrierOfflineError`

### Requirement: Command acknowledgement and events
The gateway SHALL accept an acknowledgement for a command from the device it was addressed to, exactly once in effect: `opened` marks it `executed`, `refused` marks it `rejected` and notifies the lot's members; a retried acknowledgement SHALL return the original status; an acknowledgement for another device's command SHALL be refused with `BarrierCommandNotFoundError`. The gateway SHALL record device events (`opened`, `closed`, `loop_retrigger`, `obstruction`, `tamper`, `power_restored`, `fault`, `fault_cleared`) idempotently by `client_ref`, and SHALL notify the lot's admins of `obstruction`, `tamper`, `power_restored` and `fault` at most once per device and event type per 10 minutes.

#### Scenario: Ack executes
- **WHEN** the barrier acknowledges `opened` for its delivered command
- **THEN** the command status is `executed`

#### Scenario: Ack is idempotent
- **WHEN** the same acknowledgement is sent twice
- **THEN** both answers report `executed` and one result is stored

#### Scenario: Ack for another device
- **WHEN** barrier 8 acknowledges a command addressed to barrier 7
- **THEN** the gateway answers 404 `BarrierCommandNotFoundError` and the command is unchanged

#### Scenario: Refusal alerts the desk
- **WHEN** a barrier acknowledges `refused` with reason `expired`
- **THEN** the command is `rejected` and each member of the lot receives one `barrier_command_failed` notification

#### Scenario: Events are idempotent
- **WHEN** the same `client_ref` is posted twice
- **THEN** one event row exists

#### Scenario: Non-barrier device
- **WHEN** a camera calls a barrier route
- **THEN** the gateway answers 403 `DeviceKindNotAllowedError`

### Requirement: Signed over-the-air updates
The system SHALL let a platform admin register a firmware release (kind, semantic version, SHA-256, size, storage path, secure version), SHALL offer a barrier only a released version newer than its current one, and SHALL serve the image only for released versions of the device's kind from a bucket not readable by clients. The firmware SHALL install an image only while idle (arm closed, no command in flight), SHALL verify the manifest SHA-256 and the bootloader's signature check, SHALL roll back to the previous image when the new one does not confirm itself after its first successful poll, and SHALL refuse images with a lower secure version.

#### Scenario: Newer release offered
- **WHEN** release 1.1.0 exists and a barrier reports `current=1.0.0`
- **THEN** the manifest route answers 200 with version, SHA-256, size and image path

#### Scenario: Already current
- **WHEN** the barrier reports `current=1.1.0`
- **THEN** the answer is 204

#### Scenario: Unreleased image not served
- **WHEN** a device requests the image of a version with `released = false`
- **THEN** the gateway answers 404 `NotFoundError`

#### Scenario: Non-admin cannot register a release
- **WHEN** a lot admin who is not a platform admin calls `release_device_firmware`
- **THEN** the system raises `AdminRequiredError`

#### Scenario: Corrupt image
- **WHEN** the streamed image's SHA-256 does not match the manifest
- **THEN** the firmware discards it, keeps running the current image and reports a `fault` event

#### Scenario: OTA only when idle
- **WHEN** an update is available while the arm is open
- **THEN** the firmware defers the update until the state is closed with no command in flight

### Requirement: Barrier screen
The app SHALL provide `/barrier` for operators and admins that lists the lot's barriers with direction, status (text and icon) and last command, offers per barrier an Open action that requires a reason and an explicit confirmation, tracks the resulting command until it is executed, rejected or expired, shows the history, and lets admins edit the configuration. It SHALL render four states (loading skeleton, list, empty with guidance, error with retry). The Open action SHALL be disabled for a barrier that is not online or has a command in flight and SHALL NOT be available offline.

#### Scenario: Open with a reason
- **WHEN** the operator taps Open, types a valid reason and confirms
- **THEN** the screen shows "Abriendo…" and then "Barrera abierta" when the command is executed

#### Scenario: Reason required
- **WHEN** the operator confirms with an empty reason
- **THEN** the dialog shows the localized validation message and sends nothing

#### Scenario: Failed command
- **WHEN** the command ends `expired`
- **THEN** the screen shows the failure with the reason

#### Scenario: Offline barrier
- **WHEN** a barrier's status is not online
- **THEN** its Open button is disabled and the hint about using the key or remote is shown

#### Scenario: Operator cannot edit configuration
- **WHEN** an operator opens `/barrier`
- **THEN** the configuration action is not shown
