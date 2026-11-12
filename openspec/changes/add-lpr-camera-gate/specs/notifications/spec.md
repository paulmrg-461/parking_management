## ADDED Requirements

### Requirement: Plate recognition alerts
The system SHALL create notifications of type `lpr_pending`, `lpr_exit` and `lpr_blacklisted` for every active member of the lot of the event, as specified by the `lpr-gate` capability, with the plate and event id in `data` and a dedupe key per event and user, and SHALL NOT notify members of other lots.

#### Scenario: Exit alert reaches an operator
- **WHEN** an exit event with reason `exit_unpaid` is created in lot 1
- **THEN** an active operator of lot 1 receives one `lpr_exit` notification whose `data.plate` is the plate

#### Scenario: No duplicate on replay
- **WHEN** the same read is replayed with its `client_ref`
- **THEN** no additional notification is created
