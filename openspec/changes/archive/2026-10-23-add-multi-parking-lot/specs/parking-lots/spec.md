## ADDED Requirements

### Requirement: Multiple parking lots

The system SHALL store any number of parking lots in `public.parking_lots`
(name, unique code, address, timezone, active flag) and SHALL let platform
admins create and update them through `create_lot` and `update_lot`. Data that
belongs to a site (categories, tariffs, sessions, shifts, monthly passes, pass
payments, reservations, settings, notifications and browser push subscriptions)
MUST carry a `lot_id` and MUST never be visible or writable outside that lot.
Vehicles SHALL remain a global registry keyed by plate so the same car can park
at any lot.

#### Scenario: Two lots run the same category names
- **WHEN** an admin creates lots `north` and `south` and each one configures a
  category named `car`
- **THEN** both categories exist independently with their own capacity and
  tariffs

#### Scenario: Existing installation upgrades without action
- **WHEN** the migration runs on a database with data and no `parking_lots` rows
- **THEN** it seeds a `default` lot, attaches every existing row to it and gives
  every existing user a membership, so the app keeps working unchanged

#### Scenario: Operator cannot create a lot
- **WHEN** an operator calls `create_lot`
- **THEN** the server raises `AdminRequiredError` and no lot is created

### Requirement: Active lot resolution

Every lot-scoped read or write SHALL resolve the active lot from the
`x-lot-id` request header through `current_lot_id()`, which MUST validate that
the caller belongs to that lot and MUST raise `LotRequiredError` otherwise. When
the header is absent the helper SHALL fall back to the caller's default lot (the
lowest `lot_members.lot_id`). Client-supplied lot ids inside RPC parameters MUST
NOT override this resolution for writes.

#### Scenario: Header selects the lot
- **WHEN** an operator who belongs to lots 1 and 2 sends `x-lot-id: 2` and reads
  `parking_sessions`
- **THEN** only lot 2 sessions are returned

#### Scenario: Forged header is rejected
- **WHEN** a user who belongs only to lot 1 sends `x-lot-id: 2`
- **THEN** the request fails with `LotRequiredError` and no row is returned

#### Scenario: Header omitted
- **WHEN** a user with memberships in lots 1 and 2 omits the header
- **THEN** the request is served against lot 1 (the lowest membership)

### Requirement: Per-lot membership and roles

The system SHALL store a role per `(user, lot)` in `public.lot_members`
(`operator` or `admin`). Lot admins SHALL manage categories, tariffs, monthly
passes and reservations of their lot; only platform admins SHALL create lots,
move users between lots or promote a user to platform admin. A user MUST NOT be
able to remove the last lot admin of a lot.

#### Scenario: Lot admin manages only his site
- **WHEN** the admin of lot 1 updates a category of lot 2
- **THEN** the server raises `AdminRequiredError` and the category is unchanged

#### Scenario: Last lot admin cannot be demoted
- **WHEN** the only admin of a lot is demoted to operator
- **THEN** the server raises `LastAdminError` and the membership is unchanged

### Requirement: Lot-scoped operations

Check-in, check-out, capacity enforcement, shifts, reservations and reports
SHALL operate on `(lot_id, …)` keys. Capacity MUST be enforced per
`(lot, category)` including active reservations, shifts MUST be unique per
`(operator, lot)`, ticket numbers MUST carry the lot code, and occupancy and
revenue reports MUST cover only the active lot unless a platform admin
explicitly requests the consolidated view.

#### Scenario: Capacity is per lot
- **WHEN** lot 1 has one free slot and lot 2 is empty, and a car checks in at
  lot 2
- **THEN** the check-in succeeds even if lot 1 is full

#### Scenario: Operator opens one shift per site
- **WHEN** an operator opens a shift at lot 1 and then at lot 2
- **THEN** both shifts stay open and each reconciles only its own lot's cash

#### Scenario: Consolidated revenue is admin-only
- **WHEN** an operator calls `report_revenue_all`
- **THEN** the server raises `AdminRequiredError`

### Requirement: Lot-aware client context

The Flutter app SHALL keep the active lot in a `LotContext` persisted locally,
SHALL send `x-lot-id` on every Supabase request, SHALL show a switcher only to
users with more than one membership, and SHALL key every lot-scoped local cache
by lot id. Offline mutations MUST capture the lot where the operator acted and
replay against that same lot.

#### Scenario: Switching lots refreshes the screen
- **WHEN** a multi-lot operator switches from lot 1 to lot 2
- **THEN** the dashboard, shift card and lists reload for lot 2 and no lot 1 row
  remains on screen

#### Scenario: Queued check-in keeps its lot
- **WHEN** an operator checks a car in offline at lot 1 and later reconnects
  while the active lot is lot 2
- **THEN** the queued check-in is replayed into lot 1

#### Scenario: Offline cold start
- **WHEN** the app starts with no network and a previously selected lot in
  storage
- **THEN** it renders that lot's cached data without prompting for a lot
