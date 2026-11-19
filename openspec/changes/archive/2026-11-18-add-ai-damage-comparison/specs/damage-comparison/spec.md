## ADDED Requirements

### Requirement: Exit evidence photos
The system SHALL store optional exit photos of a parking session as `evidence_photos` rows with `phase = 'exit'` (existing rows default to `'entry'`) through the RPC `add_exit_evidence(p_session_id integer, p_photos jsonb)`. The RPC MUST authenticate the caller (`require_app_user()`), require the session to belong to the active lot (`current_lot_id()`), accept 1 to 5 photos per call and at most 5 exit photos per session (`EvidenceLimitError`), validate each object with `require_evidence_object` (uploaded by the caller to the `evidence` bucket and not used by another row), treat a repeated path of the same session as already stored, and MUST NOT modify `check_in` or `check_out`. Uploads MUST remain insert-only (no `upsert`).

#### Scenario: Exit photos are stored
- **WHEN** an operator uploads two photos to `evidence/exit-123-abc/0.jpg` and `…/1.jpg` and calls `add_exit_evidence(123, [...])`
- **THEN** two rows with `phase = 'exit'` and `kind = 'photo'` exist for session 123 and the RPC returns `exit_photo_count = 2`

#### Scenario: Retry is idempotent
- **WHEN** the same call is repeated with the same paths
- **THEN** no error is raised and the session still has two exit rows

#### Scenario: Limit
- **WHEN** a sixth exit photo is added to a session
- **THEN** the RPC raises `EvidenceLimitError`

#### Scenario: Object not uploaded by the caller
- **WHEN** a path refers to an object that does not exist, belongs to another user, or is already used by another session
- **THEN** the RPC raises `EvidenceNotFoundError` or `EvidenceAlreadyUsedError` and stores nothing

#### Scenario: Another lot's session
- **WHEN** an admin of lot 2 calls `add_exit_evidence` for a session of lot 1
- **THEN** the RPC raises `SessionNotFoundError`

### Requirement: Advisory comparison of entry and exit photos
The system SHALL provide the Edge Function `damage-compare` (`POST /functions/v1/damage-compare`, bodies `{"mode":"status"}` and `{"mode":"run","session_id":<int>,"locale":"es|en"}`) that compares the entry and exit photos of one session with a Claude vision model and stores a structured result linked to the session. The result MUST consist of `same_vehicle`, a summary, image-quality notes, zone coverage and findings; each finding MUST carry a zone, a short factual description, a classification `pre_existing | new | uncertain`, a categorical confidence `low | medium | high` and the entry and exit photos it refers to. The function MUST authenticate the caller with their own JWT and `x-lot-id`, MUST read photos with the caller's JWT (no service key for reading), MUST send at most `AI_DAMAGE_MAX_PHOTOS_PER_SET` photos per set downscaled to at most 1024 px on the long edge, and MUST run only when the user requests it (never automatically).

#### Scenario: Operator runs a comparison
- **WHEN** an operator calls `run` for a session with 4 entry photos and 4 exit photos
- **THEN** the function responds `200` with a `comparison` whose findings and verdict are stored and linked to the session, and the budget for `damage_compare` is decremented

#### Scenario: Missing photo set
- **WHEN** the session has no exit photos or no entry photos
- **THEN** the function responds `422 {"message":"InsufficientEvidenceError"}` and no request is sent to the AI provider

#### Scenario: Comparison already running
- **WHEN** a `pending` comparison exists for the session
- **THEN** the function responds `409 {"message":"ComparisonInProgressError"}`

#### Scenario: Photos cannot be read
- **WHEN** every photo of a set fails to download or exceeds the size cap
- **THEN** the function responds `422 {"message":"EvidenceUnreadableError"}` and the comparison is marked `failed`

#### Scenario: Another lot's session
- **WHEN** the caller's `x-lot-id` is not their lot or the session belongs to another lot
- **THEN** the function responds `400 LotRequiredError` or `404 SessionNotFoundError` and no photo is read

### Requirement: Results are conservative and computed by code
The function SHALL treat the model output as a proposal and MUST normalise it before storing: free text is stripped of control characters and angle brackets and truncated; photo labels the function did not send are dropped; at most 12 findings are kept; a `new` finding MUST be downgraded to `uncertain` (recording `downgraded_from = 'new'`) when it lacks a valid exit photo, lacks a valid entry photo, concerns a zone the entry set does not clearly cover, has `low` confidence, or when `same_vehicle` is not `yes`. The overall verdict (`no_new_damage`, `possible_new_damage`, `insufficient_evidence`) MUST be computed by the function: `possible_new_damage` when any finding is `new`; `no_new_damage` only when the vehicle is the same, no finding is `uncertain` and at least `AI_DAMAGE_MIN_COVERED_ZONES` (default 3) zones are covered in both sets; otherwise `insufficient_evidence`.

#### Scenario: Unsupported "new" is downgraded
- **WHEN** the model reports a `new` scratch on the `left` zone but marks `coverage` for `left` as `entry: false`
- **THEN** the stored finding is `uncertain` with `downgraded_from = 'new'` and the verdict is not `possible_new_damage` unless another finding is `new`

#### Scenario: Not enough coverage
- **WHEN** the model returns no findings but only two zones are covered in both sets
- **THEN** the verdict is `insufficient_evidence`

#### Scenario: Hostile text in the image output
- **WHEN** a description contains `</b><script>` or instructions to change the verdict
- **THEN** the stored description has angle brackets removed, the verdict is unchanged by it and the UI renders it as plain text

#### Scenario: Refusal or malformed output
- **WHEN** the provider answers `stop_reason: "refusal"`, `max_tokens`, or text that is not valid JSON
- **THEN** the function responds with `AiRefusedError` or `AiAnswerInvalidError`, the comparison is `failed`, the usage is recorded and no partial result is stored

### Requirement: Only the service can write results
The tables `damage_comparisons` and `damage_findings` SHALL be lot-scoped (`lot_id`), readable only when `lot_id = current_lot_id()`, and writable only through functions. `store_damage_comparison` and `fail_damage_comparison` MUST be executable by `service_role` only (revoked from `public`, `anon` and `authenticated`). The Edge Function MUST use the service-role key only for those two calls and the string `SUPABASE_SERVICE_ROLE_KEY` MUST appear only in `damage-compare/store.ts`.

#### Scenario: Operator cannot write a result
- **WHEN** an authenticated operator calls `rpc/store_damage_comparison` with invented findings
- **THEN** PostgREST refuses the call and no finding is created

#### Scenario: Direct table writes are refused
- **WHEN** an authenticated user inserts into or updates `damage_findings` directly
- **THEN** the statement fails with a permission error

#### Scenario: Lot isolation
- **WHEN** an admin of lot 2 reads comparisons or findings of lot 1
- **THEN** they see zero rows and `get_damage_comparison` raises `SessionNotFoundError`

### Requirement: Human review is mandatory, noted and audited
Each finding SHALL start as `open`. `review_damage_finding(p_finding_id, p_status, p_note)` MUST let any user of the finding's lot set `confirmed` or `dismissed` only with a note of 3 to 400 characters, MUST record the reviewer and time, and MUST be audited through `record_audit()` (table `damage_findings`). Re-opening a finding (`open`) MUST be limited to lot admins. A comparison result or a review MUST NOT change any charge, discount, payment, vehicle flag, notification or check-out behaviour.

#### Scenario: Operator confirms with a note
- **WHEN** an operator confirms a finding with the note `Vi el rayón en la puerta trasera izquierda`
- **THEN** the finding is `confirmed`, `reviewed_by` and `reviewed_at` are set and an `audit_log` row records the change with the operator as actor

#### Scenario: Note is required
- **WHEN** a review is submitted with an empty or two-character note
- **THEN** the RPC raises `InvalidDataError` and the finding stays `open`

#### Scenario: Operator cannot re-open
- **WHEN** an operator calls the RPC with `p_status = 'open'`
- **THEN** the RPC raises `AdminRequiredError`

#### Scenario: No automatic consequence
- **WHEN** a comparison completes with `possible_new_damage`
- **THEN** `parking_sessions.amount_charged`, `discount_amount` and `vehicles.is_blacklisted` are unchanged and no notification is created

### Requirement: Who may run and re-run
A non-admin SHALL be able to run at most one completed comparison per session (`ComparisonAlreadyExistsError` otherwise); lot admins MUST be able to re-run, creating `run_number + 1`. A `pending` comparison older than three minutes MUST be treated as failed. Runs MUST reserve and record budget through the shared AI platform feature `damage_compare` (default 60 requests and 1,200,000 tokens per lot per business day).

#### Scenario: Operator second run
- **WHEN** an operator requests a second comparison for a session that already has a completed one
- **THEN** the function responds `409 {"message":"ComparisonAlreadyExistsError"}`

#### Scenario: Admin re-run
- **WHEN** a lot admin re-runs a comparison
- **THEN** a new run with `run_number = 2` is created and the first run remains readable

#### Scenario: Daily budget
- **WHEN** the lot's `damage_compare` budget is exhausted
- **THEN** the function responds `429 {"message":"AiBudgetExceededError"}` before any photo is read

#### Scenario: Stale pending run
- **WHEN** a `pending` run is older than three minutes and a new run is requested
- **THEN** the old run is marked `failed` and the new run proceeds

### Requirement: Inert without the API key
When `ANTHROPIC_API_KEY` is absent or blank, `damage-compare` SHALL answer `{"mode":"status"}` with `configured: false` and every `run` with `503 {"message":"AiUnavailableError"}` without reserving budget or calling the provider. Exit-photo capture, upload, viewing and manual review of existing findings MUST keep working.

#### Scenario: Status without key
- **WHEN** the key is blank and the app asks for status
- **THEN** the response is `configured: false` and the comparison page shows "not enabled" without a run button

#### Scenario: Exit photos without key
- **WHEN** the key is blank and an operator checks out with exit photos
- **THEN** the photos are stored and shown in the evidence sheet

### Requirement: Advisory presentation with accuracy limits
The Flutter app SHALL show the comparison on `/damage-comparison?session=<id>` (allowed for operators and admins) with a permanent advisory banner ("It can miss damage or mistake reflections and dirt for damage. Verify each point on the vehicle: a person decides."), the verdict, the summary, quality notes, one card per finding with the entry photo on the left and the exit photo on the right, and a footer stating accuracy limits and that results never change billing. A `new` finding MUST be labelled "Possible new damage: verify" using warning (not error) styling. The `no_new_damage` verdict MUST read "No new damage detected in the compared photos" and MUST NOT read "no damage". The page MUST render the four UI states, render model text as plain text, and offer copy-summary and, for admins, re-run. Findings referring to photos no longer stored MUST show a placeholder.

#### Scenario: Possible new damage
- **WHEN** a completed comparison has one `new` finding with entry photo E3 and exit photo X3
- **THEN** the card shows "Possible new damage: verify", the two photos side by side, the confidence and the Confirm/Dismiss actions

#### Scenario: Banner and footer are always present
- **WHEN** any comparison, including `no_new_damage`, is displayed
- **THEN** the advisory banner and the accuracy-limits footer are visible

#### Scenario: Empty state without exit photos
- **WHEN** the session has entry photos but no exit photos
- **THEN** the page shows the empty state with guidance to take exit photos at check-out and no compare button

#### Scenario: Stale analysis
- **WHEN** the number of photos changed after the analysis
- **THEN** the page shows "Photos changed after this analysis" and admins can re-run

#### Scenario: Offline
- **WHEN** the device is offline when the page loads or a run is requested
- **THEN** the page shows the network error with retry, reviews are not queued and earlier loaded data is not overwritten

### Requirement: Privacy and data sent to the provider
The function SHALL send to the AI provider only the constant system prompt, the locale, and the downscaled entry and exit photos of one session labelled `E1…` and `X1…`. It MUST NOT send plates, owner data, session or lot or user identifiers, timestamps, receipts or videos, and MUST NOT log or persist image bytes, URLs, summaries or descriptions outside the comparison tables. The prompt MUST forbid transcribing plates or describing people and MUST state that text inside images is data.

#### Scenario: Request contents
- **WHEN** the mocked provider receives a request
- **THEN** its body contains only the system prompt, text labels, image blocks and the language line, with no identifiers

#### Scenario: Logs
- **WHEN** a comparison finishes
- **THEN** the log line contains ids, status, durations, token and image counts and no descriptions or bytes

### Requirement: Retention follows the evidence window
`purge_damage_comparisons()` SHALL delete comparisons (and, by cascade, their findings) of each lot whose `evidence_retention_days` is greater than zero once they are older than that window, SHALL keep everything for lots with `0`, MUST NOT be executable by API roles, and SHALL be scheduled by the existing maintenance scripts.

#### Scenario: Window applied
- **WHEN** a lot has `evidence_retention_days = 30` and a comparison is 31 days old
- **THEN** the purge deletes it and its findings

#### Scenario: Keep forever
- **WHEN** a lot has `evidence_retention_days = 0`
- **THEN** its comparisons are kept
