## ADDED Requirements

### Requirement: Pricing rules per lot
The system SHALL let an admin of the lot create, update, deactivate and delete pricing rules with a name unique in the lot (1 to 80 characters), a priority (0 to 1000), an optional vehicle group (`car`, `moto`, `heavy`), an optional occupancy band (0 to 100 percent, minimum not above maximum), an optional weekday mask (1 to 127, Monday = 1) and an optional local time window (both times or neither, different from each other, crossing midnight when the start is later than the end), a multiplier (1000 to 50000 basis points) and a flat surcharge (0 to 100000000 minor units), with at least one effect different from the identity. Every change SHALL be written to `audit_log` with the actor. A value out of range SHALL raise `InvalidPricingRuleError`, a repeated name `DuplicatePricingRuleError` and an unknown or foreign id `PricingRuleNotFoundError`.

#### Scenario: Create a rule
- **WHEN** an admin saves "Alta ocupacion" for cars with occupancy 80 to 100 and multiplier 12000
- **THEN** the rule exists for the lot, is returned by `list_pricing_rules` and the audit log records the creation

#### Scenario: Duplicate name
- **WHEN** an admin saves a second rule with the same name in the same lot
- **THEN** the system raises `DuplicatePricingRuleError`

#### Scenario: Rule without effect
- **WHEN** an admin saves a rule with multiplier 10000 and surcharge 0
- **THEN** the system raises `InvalidPricingRuleError`

#### Scenario: Operator cannot manage rules
- **WHEN** an operator calls `save_pricing_rule`, `delete_pricing_rule` or `list_pricing_rules`
- **THEN** the system raises `AdminRequiredError` and nothing changes

### Requirement: Lot guard rails and inert default
The system SHALL keep `pricing_enabled` (default false), `pricing_floor_bps` (1000 to 10000, default 10000), `pricing_ceiling_bps` (10000 to 50000, default 15000) and `pricing_round_to` (1 to 1000, default 1) per lot, editable only by a lot admin through `set_pricing_settings` (out of range raises `InvalidPricingSettingsError`). WHILE `pricing_enabled` is false the system SHALL write no lock and every fare SHALL equal the tariff fare.

#### Scenario: Disabled lot
- **WHEN** a lot has rules but `pricing_enabled = false` and a vehicle enters
- **THEN** the session has no `pricing_lock` and its fare equals the tariff fare

#### Scenario: Invalid guard rails
- **WHEN** an admin sets a floor of 11000 or a ceiling of 9000
- **THEN** the system raises `InvalidPricingSettingsError` and keeps the previous values

### Requirement: Rule matching and winner
The system SHALL evaluate only active rules of the session's lot in the lot's `business_timezone` at the entry instant. A rule SHALL match WHEN its group is null or equals the vehicle's group, its occupancy band contains the group occupancy `floor(100 * (open sessions + active holds) / group capacity)` (a rule with an occupancy bound never matches when the capacity is unknown), and its weekday and time window contain the local entry time (the weekday bit of a window crossing midnight is that of the day on which it starts). Among matching rules the highest priority SHALL win, ties going to the lowest id; rules SHALL NOT stack.

#### Scenario: Occupancy band
- **WHEN** 17 of 20 car spaces are used or held and a car enters
- **THEN** a car rule with band 80 to 100 matches

#### Scenario: Window crossing midnight
- **WHEN** a rule has window 22:00 to 06:00 and a car enters at 01:00
- **THEN** the rule matches, and at 06:00 it does not

#### Scenario: Priority decides
- **WHEN** two rules match and their priorities are 200 and 100
- **THEN** the session is locked with the rule of priority 200 only

#### Scenario: Unknown capacity
- **WHEN** a heavy vehicle enters and the only matching rule has an occupancy band
- **THEN** that rule does not match and no lock is written

### Requirement: Rate locked at entry
The system SHALL write `parking_sessions.pricing_lock` in a `BEFORE INSERT` trigger from the winning rule, copying the rule's effect and the lot's floor, ceiling and rounding step, and SHALL refuse any later change of the column with `PricingLockImmutableError`. The effective gross SHALL be computed from the lock alone: `raw = round_half_up(base * multiplier_bps / 10000) + surcharge_amount`, clamped to `[round_half_up(base * floor_bps / 10000), round_half_up(base * ceiling_bps / 10000)]`, then rounded half up to `pricing_round_to`. A failure inside the trigger SHALL leave the session without a lock and SHALL NOT block the entry.

#### Scenario: Lock survives rule changes
- **WHEN** a session is locked with a 12000 multiplier and an admin deletes the rule and raises the ceiling
- **THEN** the session's gross at check-out still uses the stored snapshot

#### Scenario: Multiplier then ceiling
- **WHEN** a lock has multiplier 20000 and ceiling 15000 and the base fare is 9000
- **THEN** the gross is 13500 and the pricing line reports `clamped = ceiling`

#### Scenario: Lock is immutable
- **WHEN** anyone updates `pricing_lock` of an existing session
- **THEN** the system raises `PricingLockImmutableError`

#### Scenario: Pricing failure never blocks entry
- **WHEN** the lock computation raises inside the trigger
- **THEN** the session is inserted with no lock

### Requirement: Offline replays are never surcharged
WHEN a session is inserted with an entry time older than five minutes before the insert (a queued offline check-in), the system SHALL keep a lock only if applying it to the category's hourly tariff does not exceed that tariff, and SHALL mark it `source = 'offline'`.

#### Scenario: Surcharge dropped
- **WHEN** a Saturday check-in with a flat 2000 surcharge rule is replayed an hour later
- **THEN** the session has no lock and pays the tariff fare

#### Scenario: Discount kept
- **WHEN** a night rule with multiplier 9000 matches a replayed check-in
- **THEN** the session keeps the lock with source `offline`

### Requirement: Public holds promise their price
The system SHALL store a lock on every `public` hold of a lot with pricing enabled (the identity lock when no rule matches), and WHEN a session consumes that hold the system SHALL use the cheaper of the hold lock and the lock computed now, comparing both applied to the category's hourly tariff, a tie keeping the hold lock. Holds created by operators (`source = 'app'`) SHALL carry no lock.

#### Scenario: Booked cheap, arrives at peak
- **WHEN** a hold booked with no rule arrives when a 12000 rule matches
- **THEN** the session has no lock and pays the tariff fare

#### Scenario: Booked at peak, arrives quiet
- **WHEN** a hold locked at 12000 arrives when no rule matches
- **THEN** the session has no lock

#### Scenario: Operator hold
- **WHEN** an operator creates a hold
- **THEN** its `pricing_lock` is null

### Requirement: Current price is visible
The system SHALL expose the current price to the customer and the operator: `public_availability` SHALL keep `hourly_amount` and add per category `current_hourly_amount`, `price_rule`, `price_multiplier_bps` and `price_tier`; `pricing_quote(p_category_id)` SHALL return the quote for an authenticated user of the lot; `pricing_session_lock` SHALL return a session's stored lock and `public_reservation_pricing` a public hold's lock to the holder (hold id plus the booking phone).

#### Scenario: Public page shows the surge
- **WHEN** an anonymous client reads availability while a rule of 12000 matches for cars
- **THEN** the car category has `current_hourly_amount` 3600, `price_tier` `higher` and `hourly_amount` still 3000

#### Scenario: Quote for a foreign category
- **WHEN** an operator quotes a category of another lot
- **THEN** the system raises `CategoryNotFoundError`

#### Scenario: Hold lock needs the phone
- **WHEN** someone asks `public_reservation_pricing` with the right hold id and a wrong phone
- **THEN** the answer is null

### Requirement: Pricing is applied through the fare hook
The system SHALL replace `fare_pricing_step(p_session_id integer, p_base integer)` so that it reads the session's lock and returns the priced amount and a pricing object (`rule_id`, `rule_name`, `kind`, `multiplier_bps`, `surcharge_amount`, `delta`, `clamped`, `locked_at`, `source`), and SHALL return the base unchanged and a null pricing for a session without lock or a base of zero. Pricing SHALL NOT apply to a monthly-pass holder, to a lost ticket or to pass sales, and SHALL appear as `pricing`, never as an adjustment line.

#### Scenario: Locked session
- **WHEN** a session locked at 12000 closes with base fare 9000
- **THEN** the quote has `gross` 10800 and `pricing.delta` 1800

#### Scenario: Pass holder
- **WHEN** a locked session of a pass holder closes
- **THEN** the amount due is 0 and `pricing` is null

#### Scenario: Lost ticket
- **WHEN** a locked session closes as a lost ticket
- **THEN** the gross is the lost ticket amount and `pricing` is null

### Requirement: Simulation and impact report
An admin SHALL be able to call `pricing_simulate(p_days, p_rules)` for 1 to 90 days (otherwise `InvalidReportRangeError`) and receive, without any write, the totals the stored or candidate rules would have produced for the closed non-pass non-lost sessions of the lot, with occupancy reconstructed from entry and exit overlaps; more than 20000 sessions SHALL raise `PricingSimulationTooLargeError`. An admin SHALL be able to call `report_pricing_impact(p_start_date, p_end_date)` for the real extra revenue and discounts of locked sessions.

#### Scenario: Preview a draft rule
- **WHEN** an admin simulates 30 days with an unsaved rule
- **THEN** the answer has `sessions_considered`, `sessions_affected`, `delta` and a per-rule breakdown, and no row is written

#### Scenario: Window too large
- **WHEN** the window holds more than 20000 sessions
- **THEN** the system raises `PricingSimulationTooLargeError`

#### Scenario: Operator cannot simulate
- **WHEN** an operator calls `pricing_simulate` or `report_pricing_impact`
- **THEN** the system raises `AdminRequiredError`

### Requirement: Lot isolation
Every pricing function and table SHALL be scoped to the lot of the caller; `pricing_rules` SHALL NOT be readable by anonymous users or operators.

#### Scenario: Other lot
- **WHEN** an admin of lot 2 lists, edits or simulates
- **THEN** only lot 2 rules and sessions are read or changed, and a rule id of lot 1 raises `PricingRuleNotFoundError`

#### Scenario: Anonymous table read
- **WHEN** the anonymous role selects from `pricing_rules`
- **THEN** Postgres denies the call with insufficient privilege

### Requirement: Admin screen and visible price in the app
The app SHALL provide an admin-only `/pricing` screen with the four UI states (skeleton, list, empty with an "Add rule" action, error with retry), a rule dialog, the guard rail settings and a simulation sheet; the check-in screen SHALL show the current rate chip and the public booking page SHALL show the current and usual price, all texts localized in Spanish and English.

#### Scenario: Empty state
- **WHEN** an admin opens `/pricing` with no rules
- **THEN** the empty state with the "Add rule" action is shown

#### Scenario: Operator route
- **WHEN** an operator navigates to `/pricing`
- **THEN** the router redirects away because the route is admin-only by default

#### Scenario: Offline check-in
- **WHEN** the device is offline on the check-in screen
- **THEN** the chip shows that the rate is confirmed when synced and check-in remains possible

### Requirement: Pricing impact report
An admin SHALL be able to request, for a date range, the number of locked sessions, how many were surcharged or discounted, the extra revenue, the discounts given, the net effect and the breakdown per rule, scoped to the active lot, without changing any other revenue report.

#### Scenario: Monthly impact
- **WHEN** an admin asks for November
- **THEN** the report lists locked sessions, extra revenue and discount given

#### Scenario: Role
- **WHEN** an operator asks for it
- **THEN** the system raises `AdminRequiredError`
