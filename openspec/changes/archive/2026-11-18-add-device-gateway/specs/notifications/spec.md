## ADDED Requirements

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
