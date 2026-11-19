## ADDED Requirements

### Requirement: Shared AI helper module
The system SHALL provide one shared Edge helper module under `supabase/volumes/functions/_shared/ai/` (client factory, caller context, PostgREST helpers, budget client, errors, logging, SSE, deadline) used by every Claude-backed Edge Function. The module MUST be created by `add-report-assistant`; later features MAY add files but MUST NOT change an existing exported signature. The module MUST read the provider key only from the Edge Function environment and MUST NOT use the service-role key.

#### Scenario: One implementation
- **WHEN** a second AI Edge Function needs a model client and budget accounting
- **THEN** it imports them from `_shared/ai` instead of re-implementing them

#### Scenario: Key stays server-side
- **WHEN** the Flutter bundle and the database are inspected
- **THEN** `ANTHROPIC_API_KEY` appears only in the `functions` service environment

### Requirement: Inert without an API key
When `ANTHROPIC_API_KEY` is absent or blank the system SHALL keep every AI feature inert: a status request MUST answer `configured: false`, an ask request MUST answer `503 {"message":"AiUnavailableError"}`, and no budget reservation, `ai_requests` row or outbound call MUST be made.

#### Scenario: Status without key
- **WHEN** an admin calls `{"mode":"status"}` and the key is blank
- **THEN** the response is `200 {"configured": false, "budget": null}`

#### Scenario: Ask without key
- **WHEN** an admin asks a question and the key is blank
- **THEN** the response is `503 AiUnavailableError`, no row exists in `ai_requests` and no request reached the provider

### Requirement: Per-lot daily budget
The database SHALL enforce, per lot, per feature and per business day (in the lot's `business_timezone`), a maximum number of requests and a maximum number of tokens, with defaults from `ai_features` (report assistant: 100 requests, 1,000,000 tokens) overridable per lot through `set_ai_limit(p_feature, p_daily_requests, p_daily_tokens)` by lot admins. `ai_budget_reserve(p_feature, p_est_tokens)` MUST authenticate the caller (`require_app_user()`, `current_lot_id()`, admin check for admin-only features), take a per-lot advisory lock, count a reserved request at its reserved tokens until it is finalised, and raise `AiBudgetExceededError` when either ceiling would be exceeded. Budgets MUST NOT be shared between lots.

#### Scenario: Request ceiling
- **WHEN** a lot with `daily_requests = 1` reserves twice on the same business day
- **THEN** the second call raises `AiBudgetExceededError`

#### Scenario: Token ceiling
- **WHEN** reserved plus recorded tokens plus the new estimate exceed `daily_tokens`
- **THEN** `ai_budget_reserve` raises `AiBudgetExceededError`

#### Scenario: Lots are isolated
- **WHEN** lot 2 has consumed its whole budget
- **THEN** an admin of lot 1 can still reserve

#### Scenario: Operator cannot reserve an admin-only feature
- **WHEN** an operator calls `ai_budget_reserve('report_assistant', 1000)`
- **THEN** the call raises `AdminRequiredError`

#### Scenario: Limit change is audited
- **WHEN** a lot admin calls `set_ai_limit('report_assistant', 20, 200000)`
- **THEN** the limit applies from the next reservation and `audit_log` records an update of `ai_limits`

### Requirement: Usage accounting without content
Every reserved request SHALL be finalised by `ai_usage_record(p_request_id, p_usage)` with status, model, token counts (input, output, cache read, cache write), tool-call count, duration and error code. A row MUST be recordable only by the user who reserved it and only once. The tables `ai_requests` and `ai_limits` MUST be readable only by admins of their own lot and writable only through the security-definer functions. The function logs and `ai_requests` MUST NOT contain question text, answers, tool results, images or personal data.

#### Scenario: Record closes the reservation
- **WHEN** the function records `status: "ok"` with token counts
- **THEN** the row stores the counts, `finished_at` is set and the reserved amount is replaced by the real usage in the budget

#### Scenario: Double record is rejected
- **WHEN** the same request id is recorded twice
- **THEN** the second call raises `AiRequestNotFoundError`

#### Scenario: Another user cannot record
- **WHEN** a different user calls `ai_usage_record` for the request
- **THEN** the call raises `AiRequestNotFoundError`

#### Scenario: Tables are closed to operators and anon
- **WHEN** an operator selects from `ai_requests`, or the `anon` role selects from any `ai_*` table
- **THEN** the operator sees zero rows and `anon` receives a permission error

### Requirement: Usage retention
`purge_ai_requests(p_days)` SHALL delete `ai_requests` older than the larger of `p_days` and 30 days, MUST NOT be executable by `anon` or `authenticated`, and SHALL be scheduled by the existing maintenance scripts (`supabase/jobs.sh`, `supabase/notifications-cron.sh`).

#### Scenario: Floor
- **WHEN** `purge_ai_requests(1)` runs
- **THEN** rows younger than 30 days are kept

#### Scenario: Not callable by API roles
- **WHEN** an authenticated user calls `rpc/purge_ai_requests`
- **THEN** PostgREST refuses the call

### Requirement: Configurable model per feature
The model identifier of each AI feature SHALL come from an environment variable (`ANTHROPIC_MODEL_REPORT_ASSISTANT`, default `claude-sonnet-5-5`). Requests MUST NOT set `temperature`, `top_p`, `top_k`, assistant prefill, `thinking: {"type":"disabled"}` or a forced `tool_choice`, MUST use `output_config.effort`, and MUST pass assistant content blocks back unchanged in tool loops.

#### Scenario: Model override
- **WHEN** `ANTHROPIC_MODEL_REPORT_ASSISTANT=claude-haiku-5-5` is set
- **THEN** requests carry that model id and an otherwise identical body

#### Scenario: Request shape
- **WHEN** the mocked provider receives a request
- **THEN** the body has no `temperature`, `top_p`, `top_k` or `thinking` field and `tool_choice.type` is `auto`
