# vehicle-history Specification

## Purpose
TBD - created by archiving change add-payment-and-history. Update Purpose after archive.
## Requirements
### Requirement: Look up a vehicle's history
The system SHALL return a vehicle's profile, visit count, total spent, open
session count and latest sessions for a plate.

#### Scenario: Existing vehicle
- **WHEN** a signed-in user searches an existing plate
- **THEN** the response includes its sessions newest first and the amount totals

#### Scenario: Unknown vehicle
- **WHEN** the plate does not exist
- **THEN** the request fails with `VehicleNotFoundError`

#### Scenario: Empty plate
- **WHEN** the search input is empty
- **THEN** the client rejects it before calling the server

