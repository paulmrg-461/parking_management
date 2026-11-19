## ADDED Requirements

### Requirement: Barrier alerts
The system SHALL notify every active admin of the lot with type `barrier_manual_open` whenever an operator opens a barrier manually, including the operator's name and the reason; SHALL notify every active member of the lot with type `barrier_command_failed` when a barrier command expires without being executed or is refused by the device; and SHALL notify every active admin of the lot with type `barrier_fault` when a barrier reports an obstruction, a tamper or a power restoration. Notifications SHALL NOT be duplicated for the same command or event and SHALL NOT reach members of other lots. Tapping them SHALL open `/barrier`.

#### Scenario: Manual open alerts admins
- **WHEN** an operator opens a barrier manually with the reason `Cliente sin ticket`
- **THEN** each active admin of the lot receives one `barrier_manual_open` notification containing the operator and the reason

#### Scenario: Expired command alerts the desk
- **WHEN** a command stays undelivered until it expires
- **THEN** each active member of the lot receives one `barrier_command_failed` notification

#### Scenario: Tamper alerts admins only
- **WHEN** a barrier reports a `tamper` event
- **THEN** each active admin of the lot receives one `barrier_fault` notification and operators who are not admins receive none

#### Scenario: Other lots are not notified
- **WHEN** a barrier of lot 1 reports an obstruction
- **THEN** admins of lot 2 only receive nothing
