# notifications Specification

## Purpose
TBD - created by archiving change add-notifications. Update Purpose after archive.
## Requirements
### Requirement: Users receive notifications for parking events
The system SHALL create a notification for every active admin when a vehicle
checks in, checks out, or a monthly pass expires in three days, without
duplicating notifications for the same event.

#### Scenario: Check-in notifies admins
- **WHEN** an operator checks a vehicle in
- **THEN** each active admin gets one notification with the plate and entry time

#### Scenario: Replayed check-in does not duplicate
- **WHEN** the same check-in request is replayed with its idempotency key
- **THEN** the existing notification is not inserted again

### Requirement: Notifications are private to their user
The system SHALL restrict notification reads to the authenticated owner;
anonymous clients SHALL have no access, and users SHALL NOT create or edit
notifications directly.

#### Scenario: Another user's notifications are hidden
- **WHEN** an operator subscribes or queries notifications
- **THEN** only rows whose `user_id` matches their profile are returned

### Requirement: Live in-app delivery
The system SHALL publish new notification rows through Supabase Realtime so a
connected client can show the unread count and banner without polling.

#### Scenario: New row arrives while the app is open
- **WHEN** a notification is inserted for the signed-in user
- **THEN** the client receives it, increments the unread badge and prepends it to
  the inbox

### Requirement: Optional background push
The system SHALL deliver pending notifications to registered device tokens via
FCM when credentials are configured, and SHALL remain fully functional in-app
when they are not.

#### Scenario: Dispatch without credentials
- **WHEN** the push dispatcher runs without `FCM_SERVICE_ACCOUNT_JSON`
- **THEN** it reports `configured: false` and leaves notifications untouched

#### Scenario: Dispatch with credentials
- **WHEN** the dispatcher runs with valid credentials and a registered token
- **THEN** it sends the notification and marks it as pushed; invalid tokens are
  removed

### Requirement: Overstay alerts
The system SHALL notify admins once per day for each open session that exceeds
the configured `overstay_hours`.

#### Scenario: Vehicle exceeds the threshold
- **WHEN** a session has been open longer than `overstay_hours`
- **THEN** each active admin receives one overstay notification for that day

### Requirement: Device connectivity alerts
The system SHALL notify every active admin of a parking lot once when an enabled device of that lot has sent no accepted request for longer than the lot's `device_offline_minutes` (an integer from 2 to 1440, default 5), with a notification of type `device_offline` carrying the device id, name, kind and last-seen time. WHEN that device next sends an accepted request, the system SHALL notify the same admins once with type `device_online`. The system SHALL NOT alert for disabled devices or for devices that never connected, SHALL NOT repeat the offline alert while the same silence lasts, and SHALL NOT notify members of other lots. WHEN a request arrives with a registered key prefix and a wrong secret, the system SHALL notify the lot's admins with type `device_auth_failed` at most once per hour per device. Tapping any of these notifications SHALL open `/devices`.

#### Scenario: Device goes silent
- **WHEN** an enabled device last reported 6 minutes ago, the lot's threshold is 5 minutes and `notify_offline_devices()` runs
- **THEN** each active admin of that lot gets one `device_offline` notification and an `offline` event is recorded

#### Scenario: No duplicate while still silent
- **WHEN** `notify_offline_devices()` runs again and the device is still silent
- **THEN** no new notification is created

#### Scenario: Device returns
- **WHEN** the device sends an accepted request after being flagged offline
- **THEN** each active admin of that lot gets one `device_online` notification and an `online` event is recorded

#### Scenario: Disabled device does not alert
- **WHEN** a device was disabled by an admin and has been silent for an hour
- **THEN** `notify_offline_devices()` creates no notification for it

#### Scenario: Never-connected device does not alert
- **WHEN** a device was registered and never sent a request
- **THEN** `notify_offline_devices()` creates no notification for it

#### Scenario: Other lots are not notified
- **WHEN** a device of lot 1 goes offline
- **THEN** a user who is admin of lot 2 only receives nothing

#### Scenario: Operators are not notified
- **WHEN** a device of lot 1 goes offline
- **THEN** an operator of lot 1 who is not an admin receives nothing

#### Scenario: Invalid key attempts alert once per hour
- **WHEN** twenty requests with a registered prefix and a wrong secret arrive within one hour
- **THEN** each admin of the device's lot has exactly one `device_auth_failed` notification

