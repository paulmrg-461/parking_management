## ADDED Requirements

### Requirement: Bay sensor alerts
The system SHALL notify every active member of the lot with type `bay_mismatch` when a bay's physical occupancy disagrees with the session records for longer than the lot's grace period, and every active admin of the lot with type `bay_sensor_unhealthy` when a mapped sensor becomes stale, reports a fault or flaps, at most once per sensor per day. A mismatch SHALL NOT be re-announced for the same bay and kind within the lot's cooldown after it was resolved or dismissed. Notifications SHALL NOT be duplicated for the same mismatch and SHALL NOT reach members of other lots. Tapping them SHALL open the home dashboard.

#### Scenario: Mismatch alerts the desk
- **WHEN** a bay reports occupied for longer than the grace period with no session assigned to it
- **THEN** each active member of the lot receives one `bay_mismatch` notification naming the bay

#### Scenario: No repeat within the cooldown
- **WHEN** an operator dismisses a mismatch and the same condition persists inside the cooldown
- **THEN** no new notification is created

#### Scenario: Unhealthy sensor alerts admins only
- **WHEN** a mapped sensor stops reporting while its hub is online
- **THEN** each active admin receives one `bay_sensor_unhealthy` notification that day and operators who are not admins receive none

#### Scenario: Other lots are not notified
- **WHEN** a mismatch opens in lot 1
- **THEN** a user who is only a member of lot 2 receives nothing
