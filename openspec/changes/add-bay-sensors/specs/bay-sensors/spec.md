## ADDED Requirements

### Requirement: Sensor channels and mapping to bays
The system SHALL register a sensor for every channel (1 to 64) reported by a device of kind `sensor_hub`, up to 64 per hub, initially unmapped, and SHALL let admins of the lot map a sensor to one bay of the same lot (`parking_spots` row) and unmap it, with at most one sensor per bay and one bay per sensor. IF the bay or the hub belongs to another lot, THEN the system SHALL refuse the mapping. IF the sensor is already mapped to another bay, THEN the system SHALL raise `SensorAlreadyMappedError`; IF the bay already has a sensor, THEN `SpotHasSensorError`. WHEN a bay is deleted, the system SHALL keep its sensor, unmapped. WHEN a hub device is deleted, the system SHALL delete its sensors.

#### Scenario: New channel appears unmapped
- **WHEN** a hub reports channel 7 for the first time
- **THEN** an unmapped sensor exists for that hub and channel with health `unmapped`

#### Scenario: Admin maps a sensor
- **WHEN** an admin maps sensor 4 to bay A3 of the same lot
- **THEN** `bay_occupancy()` includes bay A3 with the sensor's state

#### Scenario: Second sensor on a bay
- **WHEN** an admin maps another sensor to a bay that already has one
- **THEN** the system raises `SpotHasSensorError`

#### Scenario: Bay of another lot
- **WHEN** an admin of lot 1 maps a sensor of a lot 1 hub to a bay of lot 2
- **THEN** the system refuses and the sensor stays unmapped

#### Scenario: Deleting the bay unmaps the sensor
- **WHEN** an admin deletes a mapped bay
- **THEN** the sensor remains and is unmapped, and the bay's open mismatches are gone

#### Scenario: Operator cannot map
- **WHEN** an operator calls `map_bay_sensor`
- **THEN** the system raises `AdminRequiredError`

### Requirement: Hub reports are authenticated, ordered and idempotent
The gateway SHALL accept `POST /v1/bays/report` only from authenticated, enabled devices of kind `sensor_hub`, with 1 to 64 channel entries (channel, state `free`, `occupied` or `error`, optional raw value, time `at`). The system SHALL apply an entry only when its `at` is later than the sensor's last report time, SHALL count other entries as ignored, and SHALL refuse a batch containing an `at` more than 5 minutes ahead of the server with `InvalidReadTimeError`. A report SHALL NOT be able to name a bay, a lot or another hub's channel. A repeated report SHALL NOT create additional events.

#### Scenario: Valid report
- **WHEN** a hub reports channel 3 occupied with a newer `at`
- **THEN** the gateway answers 200 with `accepted: 1` and the sensor's reported state is `occupied`

#### Scenario: Retried report is idempotent
- **WHEN** the same body is posted twice
- **THEN** the second answer has `ignored` equal to the entry count and no new event exists

#### Scenario: Older report ignored
- **WHEN** a report carries an `at` earlier than the last accepted one for that channel
- **THEN** it is ignored

#### Scenario: Future timestamp
- **WHEN** an entry has an `at` 10 minutes ahead
- **THEN** the system raises `InvalidReadTimeError` and applies nothing

#### Scenario: Too many entries
- **WHEN** a batch has 65 entries
- **THEN** the system raises `InvalidDataError`

#### Scenario: Barrier device is refused
- **WHEN** a device of kind `barrier` posts to `/v1/bays/report`
- **THEN** the gateway answers 403 `DeviceKindNotAllowedError`

#### Scenario: Channel limit
- **WHEN** a report would create a 65th channel on a hub
- **THEN** the system raises `ChannelLimitError`

### Requirement: Debounced effective state
The system SHALL expose for each mapped bay an effective state computed when read: `unknown` when the sensor never reported, has been silent longer than the lot's stale limit, or reports `error`; the reported state when it has been stable for at least the lot's debounce time; otherwise the state that was effective before the last change. The effective state SHALL NOT keep showing `free` or `occupied` for a silent sensor.

#### Scenario: Recent change is not yet effective
- **WHEN** a sensor changed from free to occupied 5 seconds ago and the debounce is 20 seconds
- **THEN** the effective state is `free`

#### Scenario: Stable change becomes effective
- **WHEN** the sensor has reported occupied for 30 seconds
- **THEN** the effective state is `occupied`

#### Scenario: Silent sensor
- **WHEN** the last report is older than the stale limit
- **THEN** the effective state is `unknown`

#### Scenario: Error state
- **WHEN** the sensor reports `error`
- **THEN** the effective state is `unknown` and health is `fault`

### Requirement: Sensor health
The system SHALL assign each sensor one health value, the first that applies of `unmapped`, `never_seen`, `stale` (silent longer than the stale limit), `fault` (reports `error`), `flapping` (at least the lot's per-hour limit of state changes in the last hour) and `ok`, and SHALL show it with the bay editor. WHEN a mapped sensor is stale, faulty or flapping, the system SHALL notify the lot's admins once per sensor, health and day, except when its hub is offline.

#### Scenario: Flapping sensor
- **WHEN** a sensor changes state 12 times in an hour and the limit is 12
- **THEN** its health is `flapping`

#### Scenario: Stale sensor of an online hub
- **WHEN** a mapped sensor is silent for longer than the stale limit while its hub is online
- **THEN** health is `stale` and the admins receive one `bay_sensor_unhealthy` notification that day

#### Scenario: Hub offline does not storm
- **WHEN** the hub is offline and all its sensors become stale
- **THEN** no `bay_sensor_unhealthy` notification is created for them

### Requirement: Mismatch detection
The system SHALL open a mismatch, via `evaluate_bay_mismatches()`, when for at least the lot's grace period a mapped sensor with health `ok` shows: `occupied_unassigned` (occupied, bay active, no open session assigned to the bay), `assigned_empty` (free while an open session assigned to the bay entered at least that long ago), or `occupied_out_of_service` (occupied while the bay is out of service). The system SHALL keep at most one open mismatch per bay and kind, SHALL resolve it automatically when the condition no longer holds or the sensor stops being `ok`, SHALL NOT open a new one for the same bay and kind within the lot's cooldown after the previous one was resolved or dismissed, and SHALL ignore bays without a mapped sensor. Sensors SHALL NOT change capacity, availability, check-in, check-out, billing or reservations.

#### Scenario: Car without a record
- **WHEN** bay A3 has been occupied for 4 minutes with no open session assigned to it and the grace is 3 minutes
- **THEN** a mismatch `occupied_unassigned` is open for A3

#### Scenario: Within the grace period
- **WHEN** the bay became occupied 1 minute ago
- **THEN** no mismatch is opened

#### Scenario: Session says occupied, bay is empty
- **WHEN** a session assigned to A3 entered 10 minutes ago and the sensor has shown free for 4 minutes
- **THEN** a mismatch `assigned_empty` is open

#### Scenario: Out-of-service bay in use
- **WHEN** an out-of-service bay is occupied for longer than the grace
- **THEN** a mismatch `occupied_out_of_service` is open

#### Scenario: Auto-resolution
- **WHEN** an operator checks the car in to bay A3 (session assigned) while an `occupied_unassigned` mismatch is open
- **THEN** the next evaluation resolves it with reason `auto`

#### Scenario: Unreliable sensor resolves its mismatches
- **WHEN** a sensor with an open mismatch becomes stale
- **THEN** the mismatch is resolved with reason `sensor_unreliable`

#### Scenario: Cooldown
- **WHEN** a mismatch for bay A3 and a kind was resolved 10 minutes ago, the cooldown is 30 minutes and the condition holds again
- **THEN** no new mismatch is opened

#### Scenario: Lot without sensors
- **WHEN** a lot has no mapped sensors
- **THEN** `evaluate_bay_mismatches()` does nothing for it and `bay_occupancy()` returns `sensors_enabled: false`

#### Scenario: Capacity is unaffected
- **WHEN** a bay is physically occupied with no session
- **THEN** `capacity_snapshot()` and the next `check_in` behave exactly as without sensors

#### Scenario: Another lot is unaffected
- **WHEN** a mismatch opens in lot 1
- **THEN** `bay_occupancy()` of lot 2 does not list it

### Requirement: Operators dismiss mismatches
The system SHALL let any member of the lot dismiss an open mismatch of that lot with an optional note of at most 200 characters, recording who and when. IF the mismatch does not exist or belongs to another lot, THEN the system SHALL raise `MismatchNotFoundError`; IF it is already resolved, THEN `MismatchResolvedError`.

#### Scenario: Dismiss
- **WHEN** an operator dismisses an open mismatch with the note `Vehículo de mantenimiento`
- **THEN** it is resolved with reason `dismissed` and the operator recorded

#### Scenario: Other lot
- **WHEN** an operator of lot 1 dismisses a mismatch of lot 2
- **THEN** the system raises `MismatchNotFoundError`

#### Scenario: Already resolved
- **WHEN** the mismatch was resolved automatically before the operator acted
- **THEN** the system raises `MismatchResolvedError`

### Requirement: Per-lot sensor settings
The system SHALL keep per lot the debounce (5 to 300 s, default 20), stale limit (2 to 60 min, default 5), flapping limit (3 to 120 per hour, default 12), mismatch grace (1 to 60 min, default 3) and cooldown (1 to 1440 min, default 30), changeable only by lot admins through `set_bay_sensor_settings`; a null argument keeps the current value. IF a value is out of range, THEN the system SHALL raise `InvalidDataError`. Admins SHALL also be able to set each sensor's type, threshold and hysteresis (`set_bay_sensor_threshold`), which the hub fetches with its configuration.

#### Scenario: Defaults
- **WHEN** a lot has never configured the settings
- **THEN** `get_bay_sensor_settings()` returns the defaults

#### Scenario: Out of range
- **WHEN** an admin sets the grace to 0
- **THEN** the system raises `InvalidDataError`

#### Scenario: Operator cannot change settings
- **WHEN** an operator calls `set_bay_sensor_settings`
- **THEN** the system raises `AdminRequiredError`

#### Scenario: Threshold reaches the hub
- **WHEN** an admin changes a sensor's threshold and the hub fetches `/v1/bays/config`
- **THEN** the channel's `threshold` in the response is the new value

### Requirement: Real occupancy on the slot board
The app SHALL overlay the physical state of each mapped bay on the slot board cell without changing the cell's session-based colour, using an icon and text (never colour alone) for the sensor state, and SHALL mark a bay with an open mismatch with an alert border and a label of its kind. WHEN the lot has no mapped sensors, or loading the sensor layer fails, the board SHALL render exactly as before; a failure SHALL show a muted notice and SHALL NOT block the rest of the dashboard. The dashboard SHALL list open mismatches with a Dismiss action and an empty message, and SHALL offer an "Alerts" filter only when sensors are enabled.

#### Scenario: Physical occupancy shown
- **WHEN** a bay with an open session also has a sensor that reads occupied
- **THEN** the cell keeps the occupied session colour and shows the sensor marker with the text "Sensor: ocupado" in its semantics label

#### Scenario: Mismatch marker
- **WHEN** a bay has an `occupied_unassigned` mismatch
- **THEN** the cell shows the alert border and the label "Vehículo sin registro"

#### Scenario: Lot without sensors
- **WHEN** `bay_occupancy()` returns `sensors_enabled: false`
- **THEN** no marker, no alerts card and no Alerts filter are rendered

#### Scenario: Sensor layer fails
- **WHEN** `bay_occupancy()` fails
- **THEN** the board and the other dashboard figures render normally and a muted "Los sensores no están disponibles" notice is shown

#### Scenario: Dismiss from the dashboard
- **WHEN** an operator dismisses a mismatch in the alerts card
- **THEN** the card reloads without it

### Requirement: Bay editor shows sensor health
The bay editor SHALL show, for a bay with a sensor, the hub and channel, the effective state, the health with text and icon, the last report time, the raw value with its unit, the threshold and hysteresis (editable by admins) and an action to unmap; for a bay without a sensor it SHALL list the lot's unmapped channels to assign. It SHALL render four states (loading skeleton, content, empty with guidance to register a hub, error with retry), and operators SHALL see it read-only.

#### Scenario: Health visible
- **WHEN** an admin opens the editor of a bay whose sensor is flapping
- **THEN** the health chip reads "Inestable" with its icon and the flap count is visible

#### Scenario: Assign from the editor
- **WHEN** an admin picks an unmapped channel and confirms
- **THEN** the bay shows that sensor

#### Scenario: No hubs yet
- **WHEN** no sensor has reported in the lot
- **THEN** the empty state explains how to register a hub

#### Scenario: Operator is read-only
- **WHEN** an operator opens the editor
- **THEN** threshold fields and map/unmap actions are not editable

### Requirement: Hub firmware behaviour
The reference hub firmware SHALL filter each channel (median of 5 readings and a hysteresis band) and report a state change only after it has been stable for the configured time, SHALL send changes immediately and a snapshot of all channels at the configured interval, SHALL report `error` for a channel after 3 consecutive failed reads, SHALL buffer up to 256 unsent changes while offline and send them oldest first in batches of at most 64, SHALL keep the last good configuration in non-volatile memory, SHALL never act on its own authority beyond reporting, and SHALL install only signed firmware while rolling back a failed update.

#### Scenario: Spike rejected
- **WHEN** one reading among five is a spike
- **THEN** the filtered state does not change

#### Scenario: Stable change reported
- **WHEN** the filtered state changes and stays for `stable_ms`
- **THEN** the change is reported once

#### Scenario: Offline buffer
- **WHEN** the gateway is unreachable while 300 changes occur
- **THEN** the newest 256 are kept, the dropped count is 44 and they are sent oldest first after recovery

#### Scenario: Sensor stops answering
- **WHEN** a channel fails 3 consecutive reads
- **THEN** the hub reports `error` for that channel and keeps scanning the others

#### Scenario: Config unavailable at boot
- **WHEN** the hub boots without network
- **THEN** it uses the stored configuration and starts scanning
