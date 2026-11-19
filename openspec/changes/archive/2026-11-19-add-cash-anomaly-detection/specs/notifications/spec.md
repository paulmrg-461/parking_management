## ADDED Requirements

### Requirement: Cash anomaly alerts for admins
The system SHALL create, after each detection run, at most one notification of type `cash_anomaly` per lot and per active admin of that lot, summarising the anomalies of severity `medium` or `high` that were not notified before, with their count and the number of high-severity ones. The notification SHALL be created with a dedupe key so a repeated run does not duplicate it, SHALL NOT be created for operators who are not lot admins, SHALL NOT be created for `low` severity alone, and SHALL open the Anomalies page when tapped.

#### Scenario: Admins are notified once per run
- **WHEN** a run records two new `medium` anomalies and one `high` anomaly in lot 1
- **THEN** each active admin of lot 1 receives one `cash_anomaly` notification stating 3 new and 1 high severity

#### Scenario: Re-run does not duplicate
- **WHEN** the detection runs again with no new anomalies
- **THEN** no notification is created

#### Scenario: Operators are not notified
- **WHEN** a run records anomalies in lot 1 which has an operator and an admin
- **THEN** the operator receives no `cash_anomaly` notification

#### Scenario: Low severity stays silent
- **WHEN** a run records only `low` severity anomalies
- **THEN** no notification is created and the anomalies are marked as notified

#### Scenario: Other lots are not notified
- **WHEN** a run records anomalies in lot 2
- **THEN** admins who are members of lot 1 only receive nothing

#### Scenario: Deep link
- **WHEN** an admin taps a `cash_anomaly` notification in the inbox
- **THEN** the app navigates to `/anomalies`
