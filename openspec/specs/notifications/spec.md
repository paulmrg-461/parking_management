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

