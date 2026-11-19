## ADDED Requirements

### Requirement: Per-lot device registry
The system SHALL keep a registry of hardware devices per parking lot in `public.lot_devices`, each with a kind (`camera`, `barrier` or `sensor_hub`), a name unique within the lot (1 to 60 characters after trimming), an enabled flag, the time of its last accepted request and its firmware version. WHEN a lot admin calls `register_lot_device(p_kind, p_name)`, the system SHALL create the device in the active lot and record a `registered` event. IF the kind is not one of the three values, THEN the system SHALL raise `InvalidDeviceKindError`. IF the name is empty or longer than 60 characters, THEN the system SHALL raise `InvalidDeviceNameError`. IF the lot already has a device with that name, THEN the system SHALL raise `DeviceNameTakenError`. IF the lot already has 50 devices, THEN the system SHALL raise `DeviceLimitReachedError`. IF the caller is not an admin of the active lot, THEN the system SHALL raise `AdminRequiredError` and create nothing.

#### Scenario: Admin registers a camera
- **WHEN** an admin of lot 1 calls `register_lot_device('camera', 'Entrada principal')`
- **THEN** a device of kind `camera` exists in lot 1 with `enabled = true`, status `never_seen`, and a `registered` event carries the admin as actor

#### Scenario: Duplicate name in the same lot
- **WHEN** lot 1 already has a device named `Entrada principal` and an admin registers another with the same name
- **THEN** the system raises `DeviceNameTakenError` and no device is created

#### Scenario: Same name in another lot is allowed
- **WHEN** lot 1 has a device named `Entrada principal` and an admin of lot 2 registers a device with that name
- **THEN** the device is created in lot 2

#### Scenario: Invalid kind
- **WHEN** an admin calls `register_lot_device('printer', 'X')`
- **THEN** the system raises `InvalidDeviceKindError`

#### Scenario: Operator cannot register
- **WHEN** an operator of lot 1 calls `register_lot_device('barrier', 'Salida')`
- **THEN** the system raises `AdminRequiredError` and the registry is unchanged

### Requirement: API key is issued once and stored hashed
WHEN a device is registered, the system SHALL generate an API key of the form `pkd_<12 hex>_<64 hex>`, return it in the response of that call only, and store only its 12-character prefix and the SHA-256 hash of the full key. The system SHALL NOT expose the key, its hash, the request sequence or the rate counters through `list_lot_devices`, `device_events`, `audit_log`, logs or any table readable by the `authenticated` or `anon` roles.

#### Scenario: Key returned at registration
- **WHEN** an admin registers a device
- **THEN** the response contains `api_key` matching `^pkd_[0-9a-f]{12}_[0-9a-f]{64}$` and `key_prefix` equal to its 12-character prefix

#### Scenario: Key is not readable afterwards
- **WHEN** the admin calls `list_lot_devices()` after registering
- **THEN** no element contains `api_key` or `key_hash`

#### Scenario: Registry table is closed to clients
- **WHEN** a signed-in admin or operator selects from `public.lot_devices` through PostgREST
- **THEN** the request is denied with insufficient privilege

#### Scenario: Hash never reaches the audit log
- **WHEN** a device is registered, rotated and deleted
- **THEN** `public.audit_log` contains no row whose `table_name` is `lot_devices`

### Requirement: Key rotation
WHEN a lot admin calls `rotate_lot_device_key(p_id)` for a device of the active lot, the system SHALL replace the prefix and hash with those of a newly generated key, return the new key once, reset the stored request sequence to 0 and record a `key_rotated` event. The previous key SHALL stop authenticating immediately. IF no device with that id exists in the active lot, THEN the system SHALL raise `DeviceNotFoundError`.

#### Scenario: Old key stops working
- **WHEN** an admin rotates the key of a device and the device sends a request with the old key
- **THEN** the gateway answers 401 `DeviceUnauthorizedError`

#### Scenario: New key works from sequence 1
- **WHEN** the device sends a request with the new key and `X-Device-Seq: 1`
- **THEN** the request is accepted

#### Scenario: Rotating a device of another lot
- **WHEN** an admin whose active lot is 1 calls `rotate_lot_device_key` with the id of a device of lot 2
- **THEN** the system raises `DeviceNotFoundError` and the device of lot 2 keeps its key

### Requirement: Admins manage devices of their lot
The system SHALL let a lot admin rename a device, enable or disable it and change its rate limit through `update_lot_device(p_id, p_name, p_enabled, p_rate_per_minute)` (a null argument keeps the current value), delete it through `delete_lot_device(p_id)`, and list the devices of the active lot through `list_lot_devices()` with a computed status: `disabled` when not enabled, `never_seen` when it never sent an accepted request, `offline` when its last accepted request is older than the lot's `device_offline_minutes`, otherwise `online`. Each change SHALL record an event (`renamed`, `enabled`, `disabled`, `deleted`) with the actor. IF the rate limit is outside 6..600, THEN the system SHALL raise `InvalidDataError`.

#### Scenario: Disable a device
- **WHEN** an admin calls `update_lot_device(7, null, false)`
- **THEN** the device has `enabled = false`, its status is `disabled` and a `disabled` event exists

#### Scenario: Delete keeps the history
- **WHEN** an admin deletes device 7
- **THEN** the device is gone from `list_lot_devices()` and its events remain with `device_id` null and the device name preserved

#### Scenario: List is scoped to the active lot
- **WHEN** lot 1 and lot 2 each have one device and an admin lists with lot 1 active
- **THEN** only the device of lot 1 is returned

#### Scenario: Operator cannot list
- **WHEN** an operator calls `list_lot_devices()`
- **THEN** the system raises `AdminRequiredError`

### Requirement: Devices authenticate with their API key at the gateway
The Edge Function `device-gateway` SHALL authenticate every request except `GET /v1/time` by the `X-Device-Key` header: it SHALL look the device up by the key prefix, compute the SHA-256 hash of the presented key and compare it with the stored hash in constant time. IF the header is missing, malformed, has an unknown prefix or does not match, THEN the gateway SHALL answer 401 `DeviceUnauthorizedError` with the same body in all four cases and SHALL NOT call any route RPC. The gateway SHALL take the parking lot from the registry row of the authenticated device and SHALL ignore any `x-lot-id` header and any user token. The gateway SHALL NOT accept a GoTrue user JWT as device authentication.

#### Scenario: Valid key
- **WHEN** a registered, enabled device sends `POST /v1/heartbeat` with its key, a current timestamp and a sequence greater than the stored one
- **THEN** the gateway answers 200 and the device's `last_seen_at` is updated

#### Scenario: Wrong secret for a known prefix
- **WHEN** a request carries a key with a registered prefix and a different secret
- **THEN** the gateway answers 401 `DeviceUnauthorizedError`, the device's `last_seen_at` is unchanged and an `auth_failed` event is recorded at most once per 10 minutes

#### Scenario: Unknown prefix
- **WHEN** a request carries a well-formed key whose prefix is not registered
- **THEN** the gateway answers 401 `DeviceUnauthorizedError` and nothing is written to the database

#### Scenario: User JWT is not a device credential
- **WHEN** a request carries a valid operator `Authorization: Bearer <JWT>` and no `X-Device-Key`
- **THEN** the gateway answers 401 `DeviceUnauthorizedError`

#### Scenario: Forged lot header is ignored
- **WHEN** a device of lot 1 sends a request with `x-lot-id: 2`
- **THEN** the request is processed for lot 1

#### Scenario: Disabled device
- **WHEN** a device with `enabled = false` sends a request with its correct key
- **THEN** the gateway answers 403 `DeviceDisabledError` and no route RPC runs

### Requirement: Replay protection and clock-skew bound
The gateway SHALL require `X-Device-Seq` (an integer from 1 to 2^63-1) and `X-Device-Timestamp` (Unix seconds) on every authenticated request. IF the sequence is not strictly greater than the last accepted sequence of the device, THEN the gateway SHALL answer 409 `DeviceReplayError` including `last_seq`. IF the timestamp differs from server time by more than 5 minutes in either direction, THEN the gateway SHALL answer 401 `DeviceClockSkewError` including `server_time`. In both cases no route RPC SHALL run and the stored sequence and `last_seen_at` SHALL remain unchanged. The gateway SHALL serve `GET /v1/time` without authentication, returning `server_time`.

#### Scenario: Replayed request
- **WHEN** a device's request with sequence 10 was accepted and the identical request is sent again
- **THEN** the gateway answers 409 `DeviceReplayError` with `last_seq: 10`

#### Scenario: Device recovers its counter
- **WHEN** a device that lost its counter receives `DeviceReplayError` with `last_seq: 10` and retries with sequence 11
- **THEN** the request is accepted

#### Scenario: Stale timestamp
- **WHEN** a request carries a timestamp 6 minutes in the past
- **THEN** the gateway answers 401 `DeviceClockSkewError` with `server_time`

#### Scenario: Timestamp within the bound
- **WHEN** a request carries a timestamp 4 minutes in the future
- **THEN** it is accepted

#### Scenario: Time endpoint needs no key
- **WHEN** any client sends `GET /v1/time` without headers
- **THEN** the gateway answers 200 with `server_time`

### Requirement: Per-device rate limit
The system SHALL limit each device to `rate_per_minute` accepted requests per 60-second window (default 120, configurable from 6 to 600). IF a device exceeds its limit, THEN the gateway SHALL answer 429 `DeviceRateLimitedError` with `retry_after_s` and a `Retry-After` header, and no route RPC SHALL run. The limit of one device SHALL NOT affect another device.

#### Scenario: Limit exceeded
- **WHEN** a device with `rate_per_minute = 6` sends a seventh valid request inside one minute
- **THEN** the gateway answers 429 `DeviceRateLimitedError`

#### Scenario: Window resets
- **WHEN** 60 seconds have passed since the window started
- **THEN** the next valid request is accepted

#### Scenario: Other devices are unaffected
- **WHEN** device A is rate limited and device B of the same lot sends a valid request
- **THEN** device B's request is accepted

### Requirement: Device RPCs are executable by the service role only
The functions `device_lookup`, `device_accept_request`, `device_record_auth_failure` and `device_heartbeat` SHALL be executable only by the `service_role` database role. The gateway SHALL restrict each route to the device kinds it declares; IF a device of another kind calls it, THEN the gateway SHALL answer 403 `DeviceKindNotAllowedError`.

#### Scenario: Authenticated user cannot call a device RPC
- **WHEN** a signed-in admin calls `rpc/device_accept_request`
- **THEN** Postgres denies the call with insufficient privilege

#### Scenario: Anonymous client cannot look a key up
- **WHEN** a client with the anon key calls `rpc/device_lookup`
- **THEN** Postgres denies the call with insufficient privilege

#### Scenario: Unknown route
- **WHEN** an authenticated device calls `POST /v1/does-not-exist`
- **THEN** the gateway answers 404 `NotFoundError`

### Requirement: Heartbeat and last-seen
WHEN an authenticated device sends `POST /v1/heartbeat` with an optional JSON object of health values, the system SHALL store that object as the device's `last_status`, update `last_seen_at` and `firmware_version` (from `X-Device-Firmware` when present), and answer with `server_time`, `heartbeat_interval_s` and the lot's `offline_minutes`. Every accepted request to any route SHALL update `last_seen_at`. IF the body is not a JSON object or exceeds 2 KiB, THEN the system SHALL answer 400 `InvalidDataError`.

#### Scenario: Heartbeat stores health
- **WHEN** a device posts `{"uptime_s": 120, "rssi_dbm": -60}` with `X-Device-Firmware: barrier-1.0.0`
- **THEN** the device shows `last_status` with those values, `firmware_version = 'barrier-1.0.0'` and status `online`

#### Scenario: Oversized heartbeat
- **WHEN** a device posts a heartbeat body of 4 KiB
- **THEN** the gateway answers 400 `InvalidDataError` and `last_status` is unchanged

### Requirement: Device event log
The system SHALL record in `public.device_events` every registration, key rotation, rename, enable, disable and delete with the acting user, and every online/offline transition, invalid-key attempt and refused request (replay, clock skew, rate limit, disabled) without an actor. Refused-request and invalid-key events SHALL be recorded at most once per device and reason per 10 minutes. The log SHALL be readable only by admins of the lot it belongs to, through `list_device_events(p_device_id, p_limit)` and the table's row-level policy, and SHALL never contain a key or a hash.

#### Scenario: Admin reads the history of a device
- **WHEN** an admin calls `list_device_events(7)` after registering and rotating device 7
- **THEN** the result lists `key_rotated` then `registered`, each with the actor's display name

#### Scenario: Repeated replays do not flood the log
- **WHEN** a device sends 50 replayed requests in one minute
- **THEN** exactly one `request_rejected` event with `detail.error = 'DeviceReplayError'` is recorded

#### Scenario: Admin of another lot cannot read the log
- **WHEN** an admin whose only membership is lot 2 selects `device_events` with lot 2 active
- **THEN** no event of lot 1 is returned

#### Scenario: Operator cannot read the log
- **WHEN** an operator of lot 1 selects `device_events`
- **THEN** no row is returned

### Requirement: Device management screen
The app SHALL offer lot admins a `/devices` screen that lists the lot's devices with kind, name, key prefix, status (text and icon, never colour alone), last seen and firmware, and lets them register, rename, enable/disable, rotate the key, delete, read the event history and set the offline threshold. The screen SHALL render four states: a skeleton while loading, the list on success, an empty state with a "register device" action, and an error state with retry. WHEN a key is issued, the app SHALL show it exactly once in a dialog that requires an explicit confirmation to close, SHALL NOT persist it in local storage and SHALL discard it when the dialog closes. The route SHALL be unavailable to operators. WHILE the app is offline, device actions SHALL fail with a visible message and SHALL NOT be queued.

#### Scenario: Register shows the key once
- **WHEN** an admin registers a device from the screen
- **THEN** a dialog shows the full key with a copy action and a warning, and after confirming, the key cannot be shown again

#### Scenario: Empty lot
- **WHEN** the lot has no devices
- **THEN** the screen shows the empty state with the register action

#### Scenario: Load failure
- **WHEN** listing devices fails
- **THEN** the screen shows the localized error with a retry action and no raw exception text

#### Scenario: Operator is redirected
- **WHEN** an operator navigates to `/devices`
- **THEN** the router redirects to the home route

#### Scenario: Offline action is not queued
- **WHEN** an admin taps "rotate key" with no connectivity
- **THEN** an error message is shown, no key dialog opens and the outbox is unchanged
