## ADDED Requirements

### Requirement: Deterministic anomaly rules
The system SHALL evaluate, per active lot, eight deterministic rules over committed rows and record each finding in `cash_anomalies` with a rule, a severity (`low`, `medium`, `high`), the subject user, the related shift or session and a `details` document: repeated shift shortages per operator, lost-ticket rate per operator against the lot baseline, shift adjustments after close, zero-amount check-outs that are not monthly passes, lost-ticket charges on stays shorter than a threshold, discount share per admin, shifts left open beyond a number of hours, and sessions open beyond a number of days. The rules SHALL read only rows of the lot being evaluated and SHALL NOT change any business data.

#### Scenario: Repeated shortages
- **WHEN** an operator closed three shifts in the last 14 days with differences of -6000, -5500 and -8000 and the lot's minimum shortage is 5000 with a minimum of 3 shifts
- **THEN** one `shift_shortage` anomaly of severity `medium` is recorded for that operator with a total shortage of 19500

#### Scenario: Shortage below the threshold is ignored
- **WHEN** an operator's shifts closed with differences of -200 and 0
- **THEN** no `shift_shortage` anomaly is recorded

#### Scenario: Lost-ticket rate above the baseline
- **WHEN** an operator closed 40 sessions of which 8 were lost tickets while the other operators closed 160 of which 8 were lost tickets
- **THEN** a `lost_ticket_rate` anomaly of severity `high` is recorded with a rate of 20 % and a baseline of 5 %

#### Scenario: No baseline with a single operator
- **WHEN** only one operator closed sessions in the window
- **THEN** no `lost_ticket_rate` anomaly is recorded

#### Scenario: Adjustment after close
- **WHEN** an admin changes a closed shift's difference from -6000 to -500
- **THEN** a `post_close_adjustment` anomaly of severity `high` is recorded for the shift's operator naming who adjusted

#### Scenario: Zero charge that is not a pass
- **WHEN** a closed session has `amount_charged` 0 and payment method `exempt`
- **THEN** a `zero_charge` anomaly of severity `medium` is recorded

#### Scenario: Pass exit is not flagged
- **WHEN** a closed session has `amount_charged` 0 and payment method `monthly_pass`
- **THEN** no `zero_charge` anomaly is recorded

#### Scenario: Excluded by an extension
- **WHEN** `anomaly_zero_charge_excluded` returns true for a zero-charge session
- **THEN** no `zero_charge` anomaly is recorded for it

#### Scenario: Short stay charged as lost ticket
- **WHEN** a session was closed as a lost ticket after 4 minutes and the threshold is 30 minutes
- **THEN** a `short_lost_ticket` anomaly of severity `high` is recorded

#### Scenario: Discount share per admin
- **WHEN** one admin discounted 30 of the lot's 200 closed sessions in the window with defaults of 3 discounts and 10 %
- **THEN** a `discount_rate` anomaly of severity `medium` is recorded naming that admin

#### Scenario: Shift open too long
- **WHEN** a shift has been open for 20 hours and the threshold is 16
- **THEN** a `shift_open_long` anomaly of severity `medium` is recorded

#### Scenario: Session open for many days
- **WHEN** a vehicle without an active monthly pass has been inside for 9 days and the threshold is 7
- **THEN** a `session_open_long` anomaly of severity `low` is recorded, and a vehicle with an active pass is not flagged

#### Scenario: Lot isolation
- **WHEN** lot 2 has sessions and shifts that satisfy a rule and lot 1 has none
- **THEN** every anomaly is recorded with `lot_id` 2 and none for lot 1

### Requirement: Anomalies are raised once
The system SHALL give every anomaly a dedupe key and SHALL keep at most one `cash_anomalies` row per `(lot_id, dedupe_key)`. Running the detection again over the same data SHALL create nothing. A recurrence SHALL create a new anomaly only when its key changes: a new triggering shift or session, or the next ISO week for the weekly rules. A dismissed anomaly SHALL NOT be raised again for the same key.

#### Scenario: Second run is a no-op
- **WHEN** the detection runs twice over unchanged data
- **THEN** the second run creates no rows and sends no notification

#### Scenario: New short shift extends the streak
- **WHEN** a fourth qualifying short shift closes after a `shift_shortage` anomaly was recorded
- **THEN** a new anomaly with a new key is recorded

#### Scenario: Dismissed stays dismissed
- **WHEN** an anomaly was dismissed and the detection runs again over the same data
- **THEN** the row is not recreated or reopened

### Requirement: Thresholds are per-lot admin settings
The system SHALL store the thresholds in `anomaly_settings`, one row per lot, with defaults (window 14 days, shortage 5000 minor units over 3 shifts, lost-ticket minimum 10 closed sessions, 10 % and 200 % of baseline, adjustment minimum 1000, short stay 30 minutes, 3 discounts at 10 %, shifts 16 hours, sessions 7 days) and range checks. Lot admins SHALL read and change them through `get_anomaly_settings` and `set_anomaly_settings`; a missing key SHALL keep its value. The system SHALL let an admin disable detection for a lot or for individual rules. The thresholds SHALL NOT be readable by operators.

#### Scenario: Defaults for a lot without a row
- **WHEN** an admin calls `get_anomaly_settings` for a lot with no settings row
- **THEN** a row with the defaults is created and returned

#### Scenario: Change one threshold
- **WHEN** an admin calls `set_anomaly_settings('{"session_open_days": 3}')`
- **THEN** only that value changes and the other lots are unaffected

#### Scenario: Out-of-range value
- **WHEN** an admin sets `window_days` to 1000
- **THEN** the system raises `InvalidAnomalySettingError` and nothing changes

#### Scenario: Unknown key
- **WHEN** an admin sends a key that is not a setting
- **THEN** the system raises `InvalidAnomalySettingError`

#### Scenario: Operator cannot read or change thresholds
- **WHEN** an operator selects from `anomaly_settings` or calls `get_anomaly_settings` or `set_anomaly_settings`
- **THEN** the select returns no rows and the calls raise `AdminRequiredError`

#### Scenario: Disabled rule
- **WHEN** a lot disables `zero_charge`
- **THEN** the detection records no `zero_charge` anomaly for that lot

### Requirement: Scheduled detection
The system SHALL run the detection with `detect_cash_anomalies()` from the stack's job runner (`supabase/jobs.sh` in the `supabase-jobs` container and `supabase/notifications-cron.sh`), SHALL NOT depend on pg_cron, SHALL make overlapping runs harmless, and SHALL NOT expose the detection or purge functions to `anon` or `authenticated`. Resolved anomalies older than the retention window SHALL be removed by `purge_cash_anomalies`.

#### Scenario: Job runs without a user
- **WHEN** the job runner calls `detect_cash_anomalies()` as the database owner
- **THEN** it evaluates every active lot without needing `x-lot-id`

#### Scenario: API roles cannot run it
- **WHEN** an authenticated or anonymous client calls `detect_cash_anomalies`
- **THEN** Postgres denies execution

#### Scenario: Overlapping runs
- **WHEN** two runs start at the same time
- **THEN** the second returns 0 without error

#### Scenario: Retention
- **WHEN** `purge_cash_anomalies(365)` runs
- **THEN** reviewed anomalies resolved more than 365 days ago are deleted and open ones younger than 730 days are kept

### Requirement: Review workflow
Lot admins SHALL list anomalies with `list_cash_anomalies` filtered by status, rule and severity, newest first, with the open count, and SHALL acknowledge or dismiss an open anomaly with `resolve_cash_anomaly`. A dismissal SHALL require a note of 3 to 300 characters. Resolving SHALL record who resolved it and when, and an anomaly that is not open SHALL NOT be resolved again.

#### Scenario: Acknowledge
- **WHEN** an admin acknowledges an open anomaly without a note
- **THEN** its status is `acknowledged` with the resolver and time recorded

#### Scenario: Dismiss needs a note
- **WHEN** an admin dismisses an open anomaly with an empty note
- **THEN** the system raises `AnomalyNoteRequiredError` and the anomaly stays open

#### Scenario: Already resolved
- **WHEN** an admin resolves an anomaly that is already dismissed
- **THEN** the system raises `AnomalyAlreadyResolvedError`

#### Scenario: Wrong lot
- **WHEN** an admin resolves an anomaly id that belongs to another lot
- **THEN** the system raises `AnomalyNotFoundError`

#### Scenario: Filters
- **WHEN** an admin lists with status `open` and rule `zero_charge`
- **THEN** only open zero-charge anomalies of the active lot are returned, and `open_count` still counts every open anomaly of the lot

#### Scenario: Invalid filter value
- **WHEN** an admin lists with an unknown rule name
- **THEN** the system raises `InvalidDataError`

### Requirement: Admin-only visibility
The system SHALL show anomalies, anomaly settings and their notifications only to active admins of the lot. Operators SHALL NOT read any anomaly, about themselves or others, through tables, RPCs, notifications or routes, and the anonymous role SHALL have no access.

#### Scenario: Operator reads the table
- **WHEN** an operator selects from `cash_anomalies`
- **THEN** zero rows are returned

#### Scenario: Operator calls an RPC
- **WHEN** an operator calls `list_cash_anomalies` or `resolve_cash_anomaly`
- **THEN** the system raises `AdminRequiredError`

#### Scenario: Anonymous access
- **WHEN** a client holding only the anon key selects from `cash_anomalies` or calls `list_cash_anomalies`
- **THEN** Postgres denies the request

#### Scenario: Admin sees only the active lot
- **WHEN** an admin of lots 1 and 2 sends `x-lot-id: 1`
- **THEN** only lot 1 anomalies are returned

#### Scenario: Operator route
- **WHEN** an operator opens `/anomalies`
- **THEN** the app redirects to the home screen

### Requirement: Audit trail of reviews
The system SHALL record in `audit_log` every insert and update of `cash_anomalies` and `anomaly_settings` with the acting user when there is one, so acknowledgements, dismissals with their notes and threshold changes are traceable. The Anomalies page SHALL link each anomaly to the audit trail filtered to it, and to the vehicle history or shift list when the anomaly concerns a session or a shift.

#### Scenario: Dismissal is audited
- **WHEN** an admin dismisses an anomaly with a note
- **THEN** an `audit_log` row for table `cash_anomalies` records the admin as actor and the changed status and note

#### Scenario: Threshold change is audited
- **WHEN** an admin changes a threshold
- **THEN** an `audit_log` row for table `anomaly_settings` records the changed column only

#### Scenario: Detector insert has no actor
- **WHEN** the job creates an anomaly
- **THEN** its audit row has a null actor

#### Scenario: Audit link
- **WHEN** an admin taps "Ver auditoría" on anomaly 12
- **THEN** the audit page opens filtered to table `cash_anomalies` and search `12`

### Requirement: Anomalies page states
The Anomalies page SHALL show a loading skeleton, the list of anomalies with severity, rule, subject, time and description, an empty state with a clear-filters action when a filter hides everything, and an error state with a retry action. Reviewing SHALL be unavailable offline and SHALL never be queued.

#### Scenario: Empty
- **WHEN** no anomaly is open
- **THEN** the page shows "Todo en orden" and no list

#### Scenario: Error and retry
- **WHEN** the list request fails
- **THEN** the page shows a localized message and a retry button that reloads

#### Scenario: Narrow screen
- **WHEN** the page renders at 400 px with 1.6 text scale
- **THEN** no overflow occurs and every action has a touch target of at least 48 dp

### Requirement: Zero-charge extension point
The system SHALL expose `anomaly_zero_charge_excluded(p_session_id integer)` returning false by default and not executable by API roles, so later changes can exclude explained free exits without altering the rule.

#### Scenario: Default
- **WHEN** no later change redefines the function
- **THEN** it returns false for every session

#### Scenario: Not callable from the API
- **WHEN** an authenticated client calls it
- **THEN** Postgres denies execution
