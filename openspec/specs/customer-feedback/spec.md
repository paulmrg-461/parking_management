# customer-feedback Specification

## Purpose
TBD - created by archiving change add-customer-feedback. Update Purpose after archive.
## Requirements
### Requirement: One rating per closed session
The system SHALL store at most one feedback row per parking session. A row
SHALL carry the session's lot, an integer rating from 1 to 5, an optional
comment of at most 500 characters (stored trimmed, `''` when absent) and its
creation time. Only sessions whose `exit_time` is set SHALL be rateable. The
`session_feedback` table SHALL have row level security enabled, no write grants
for client roles, and a select policy that matches the active lot
(`lot_id = current_lot_id()`), so a member of another site never reads it.

#### Scenario: First rating is stored
- **WHEN** a customer submits rating 5 with comment "Muy rápido" for a closed session of the active lot
- **THEN** exactly one row exists with that rating, the trimmed comment, the session's lot and its creation time

#### Scenario: Duplicate submission is refused
- **WHEN** the same session receives a second submission
- **THEN** the system raises `FeedbackAlreadyError` and the stored row keeps the first rating

#### Scenario: Open session is not rateable
- **WHEN** the session has no `exit_time`
- **THEN** the public lookup reports `rateable = false` and a submission raises `SessionNotFoundError`

#### Scenario: Rating and comment are validated
- **WHEN** the rating is 0, 6 or not an integer, or the comment exceeds 500 characters
- **THEN** the system raises `InvalidDataError` and stores nothing

#### Scenario: Another lot's feedback is invisible
- **WHEN** a member of lot 2 selects `session_feedback` while lot 1 has rows
- **THEN** the query returns zero rows

### Requirement: Public feedback capture
The system SHALL expose `public_feedback_session(p_session_id, p_plate)` and
`public_submit_feedback(p_session_id, p_plate, p_rating, p_comment)` to `anon`.
Both SHALL normalise the plate (uppercase, blanks removed) and require it to
match the session. The lookup SHALL return `null` for an unknown session or a
wrong plate, and otherwise an object with `lot_id`, `lot_name`, `rateable`,
`rated` and `rating`. Neither function SHALL return the plate, owner data, the
amount charged or any operator identity.

#### Scenario: Lookup for a valid receipt
- **WHEN** an anonymous caller passes a closed session and its plate
- **THEN** the lookup returns the lot name, `rateable = true` and `rated` reflecting the stored row

#### Scenario: Wrong plate reveals nothing
- **WHEN** an anonymous caller passes a valid session id with another plate
- **THEN** both functions return `null` (lookup) or raise `SessionNotFoundError` (submit) without confirming that the session exists

#### Scenario: Submission returns the stored rating
- **WHEN** `public_submit_feedback` succeeds
- **THEN** it returns `{rating, created_at}` and the lookup afterwards reports `rated = true`

#### Scenario: Anonymous table access is denied
- **WHEN** an anonymous caller selects `session_feedback` directly
- **THEN** permission is denied

### Requirement: Public feedback page
The system SHALL serve `/feedback?session=…&plate=…` as a public route with
four explicit states: loading skeleton, the survey, the submitted thank-you
screen and a localized failure with retry. A missing plate SHALL be requested
in a gate before the survey; an unknown or unrateable link SHALL show an
informative empty state instead of an error. The survey SHALL offer five stars
with accessible labels, a 48 dp touch target each, an optional comment limited
to 500 characters, and SHALL disable the submit action while a request is in
flight.

#### Scenario: Customer rates a visit
- **WHEN** the customer opens the receipt link, picks 4 stars, writes "Buen servicio" and submits
- **THEN** a success screen thanks them, names the site and offers nothing that can submit twice

#### Scenario: Already rated
- **WHEN** the link points at a session that already has a rating
- **THEN** the page shows a thank-you/already-rated state with the previous rating and no form

#### Scenario: Missing plate
- **WHEN** the link carries `session` but no `plate`
- **THEN** the page asks for the plate, and a wrong plate lands on the invalid-link state

#### Scenario: Submit failure keeps the answer
- **WHEN** the submission fails because the network dropped
- **THEN** the page shows the localized message with retry and keeps the chosen stars and the written comment

### Requirement: Satisfaction report
The system SHALL provide `feedback_summary(p_days default 30)` to platform
admins only, scoped to the active lot and its business timezone. It SHALL
return the period, the number of answers, `average_x10` (`round(avg * 10)`), the
number of closed sessions in the period, `response_rate_bp`
(`round(total * 10000 / closed_sessions)`, 0 without sessions), the count of
ratings ≤ 3, the full 1..5 distribution and the newest 20 rows of the period. A
period outside 1..365 days SHALL raise `InvalidReportRangeError`. Operators
SHALL get `AdminRequiredError` and an admin of another lot SHALL see only the
active lot's rows.

#### Scenario: Average and response rate
- **WHEN** the period has ratings 5 and 4 and 20 closed sessions
- **THEN** `average_x10` is 45, `total` is 2 and `response_rate_bp` is 1000

#### Scenario: Empty period
- **WHEN** there are no answers in the period
- **THEN** `total`, `average_x10`, `low_count` and every distribution bucket are 0 and `recent` is empty

#### Scenario: Quiet buckets are present
- **WHEN** no customer gave 2 stars
- **THEN** `distribution["2"]` is 0 and the report still lists all five buckets

#### Scenario: Recent comments are newest first
- **WHEN** two feedback rows share a timestamp
- **THEN** the row with the higher id comes first

#### Scenario: Other lot is excluded
- **WHEN** lot 2 has feedback in the same period and the admin calls with lot 1's header
- **THEN** no figure includes lot 2 rows

### Requirement: Satisfaction dashboard
The system SHALL expose an admin-only `/satisfaction` page reachable from the
management navigation. It SHALL show metric cards for the average rating, the
number of answers with the response rate, and the low ratings; the 1..5
distribution; and the latest comments with rating, plate and date. Period chips
SHALL switch 7 / 30 / 90 days without clearing the page. Loading, empty, error
with retry and success SHALL be explicit, and operators SHALL be redirected to
the home.

#### Scenario: Period switch keeps the page
- **WHEN** the admin switches from 30 to 7 days
- **THEN** the page keeps the current content until the new summary arrives and then updates it

#### Scenario: Empty state
- **WHEN** the lot has no feedback in the period
- **THEN** the page shows an informative empty state instead of a grid of zeros

#### Scenario: Operator is refused
- **WHEN** an operator opens `/satisfaction`
- **THEN** the router redirects to the home and the RPC would raise `AdminRequiredError`

### Requirement: Survey discovery on the receipt
WHEN `APP_URL` is configured, the system SHALL print a survey QR and the caption
"Califica tu visita" on the PDF and thermal receipts and SHALL append the survey
link to the WhatsApp receipt message. WHEN it is not configured, the receipts
SHALL remain unchanged with no dangling QR or URL.

#### Scenario: Configured receipt
- **WHEN** a checkout receipt is printed with a session id and `APP_URL` set
- **THEN** the receipt carries a QR whose payload is `/feedback?session=…&plate=…` with the session's plate

#### Scenario: Unconfigured receipt
- **WHEN** `APP_URL` is empty
- **THEN** no survey QR or URL is rendered and the rest of the receipt is identical

