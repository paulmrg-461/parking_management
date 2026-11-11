## ADDED Requirements

### Requirement: Reference rows carry a version
The system SHALL store an integer `version` (default 1, never below 1) on `vehicles`, `tariffs`, `categories` and `parking_settings`, and SHALL backfill existing rows to 1. The system SHALL increment `version` by exactly 1 on every update that changes at least one column, and SHALL leave it unchanged on an update that changes nothing. The system SHALL ignore any `version` value supplied by the client on insert or update.

#### Scenario: Backfill
- **WHEN** the migration is applied to a database with existing rows
- **THEN** every existing row of the four tables has `version = 1`

#### Scenario: Real change bumps
- **WHEN** an admin changes a tariff amount
- **THEN** its version increases by 1

#### Scenario: No-op keeps the version
- **WHEN** a statement updates a row to the values it already has (for example the check-in auto-registration `on conflict (plate) do update set plate = excluded.plate`)
- **THEN** the version is unchanged

#### Scenario: Forged version ignored
- **WHEN** a client updates a row and sets `version = 99`
- **THEN** the stored version is the previous one plus 1

### Requirement: Stale base writes are refused
WHEN a client writes to one of the four tables with a filter on the base version it edited from, and the stored version differs, the write SHALL affect zero rows, and the client SHALL treat zero rows with a different or missing stored row as a version conflict, never as success. The system SHALL NOT weaken row level security: the version filter is an additional predicate.

#### Scenario: Stale update
- **WHEN** an admin updates `tariffs?id=eq.7&version=eq.4` and the stored version is 5
- **THEN** zero rows are updated and the stored values are unchanged

#### Scenario: Current base
- **WHEN** the filter version equals the stored version
- **THEN** one row is updated and its version increases by 1

#### Scenario: Stale delete
- **WHEN** an admin deletes with a stale version filter
- **THEN** zero rows are deleted

#### Scenario: Operator cannot write
- **WHEN** an operator updates a tariff with the correct version
- **THEN** the write is refused by row level security exactly as before

#### Scenario: Other lot
- **WHEN** an admin of lot 1 updates a row of lot 2 with its correct version
- **THEN** zero rows are affected

### Requirement: Transition policy for clients without versions
The system SHALL keep accepting table writes that carry no version filter (last-write-wins) WHILE `parking_settings.row_version_required` is false for the lot in the `x-lot-id` header. WHILE it is true, the system SHALL refuse direct table writes to the four tables that lack the request header `x-versioned-write` with `VersionRequiredError`, and SHALL NOT refuse writes made inside RPCs. The system SHALL let lot admins turn the policy on through `set_row_version_policy(p_required boolean)` only WHEN `parking_settings.min_app_version` is not empty, raising `MinVersionRequiredError` otherwise, and SHALL refuse operators with `AdminRequiredError`.

#### Scenario: Old client keeps working
- **WHEN** the policy is off and an old client updates a tariff with no version filter
- **THEN** the update succeeds and the version increases

#### Scenario: Unaware write refused
- **WHEN** the policy is on and a table write arrives without the header
- **THEN** the system raises `VersionRequiredError` and nothing changes

#### Scenario: Aware write accepted
- **WHEN** the policy is on and the write carries the header and a current version
- **THEN** it succeeds

#### Scenario: RPC writes unaffected
- **WHEN** the policy is on and `check_in` updates a vehicle inside the RPC
- **THEN** the call succeeds

#### Scenario: Policy needs a minimum version
- **WHEN** an admin turns the policy on while `min_app_version` is empty
- **THEN** the system raises `MinVersionRequiredError` and the policy stays off

#### Scenario: Operator cannot change the policy
- **WHEN** an operator calls `set_row_version_policy`
- **THEN** the system raises `AdminRequiredError`
