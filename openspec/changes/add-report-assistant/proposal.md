## Why

The reports screen (`lib/features/reports/presentation/reports_page.dart`) answers a fixed set of questions: one date range, one revenue card, charts. An owner who wants "how much did motorcycles make last month?" or "did web bookings actually turn into cars?" has to pick a range, read several cards and do the arithmetic by hand. Every number needed for those answers already exists behind read-only, admin-gated SQL RPCs (`report_revenue`, `report_hourly_traffic`, `report_reservations`, `dashboard_trend`, `capacity_snapshot`, …); what is missing is a way to ask in plain Spanish or English and get the figure **with its source**.

## What Changes

- New Edge Function `report-assistant` (`supabase/volumes/functions/report-assistant/`): takes a natural-language question from an admin, runs a bounded Claude **tool-use** loop whose tools are a fixed allowlist of the existing read-only report RPCs, and returns a structured answer over Server-Sent Events.
- Tools are executed with the **caller's JWT and `x-lot-id`**, through PostgREST, so `require_admin()`, `require_lot_admin()`, `current_lot_id()` and RLS keep deciding what is visible. The model never writes SQL, never sees a service-role key and the function does not read `SUPABASE_SERVICE_ROLE_KEY` at all.
- The model does **no arithmetic and emits no numbers**. It returns references (`call_id` + path into a tool result) and an operation (`value`, `sum`, `difference`, `percent_change`, `share_percent`, `max_by`, `min_by`); the Edge Function resolves them against the real RPC output with integer math and returns integer minor units. The Flutter client formats money with `Money` and shows, per figure, which RPC and arguments produced it.
- New shared Edge helper module `supabase/volumes/functions/_shared/ai/` (Anthropic client factory, budget reservation/accounting, caller context, typed errors, logging) and new shared tables `ai_requests` / `ai_limits` with RPCs `ai_budget_status`, `ai_budget_reserve`, `ai_usage_record`, `set_ai_limit`, `purge_ai_requests`. **This change creates them**; `add-ai-damage-comparison` reuses them.
- Per-lot daily request and token budget, max tool iterations, per-request token ceiling and wall-clock deadlines.
- New Flutter feature `lib/features/report_assistant/` (hexagonal): chat-style admin page at `/report-assistant`, reachable from the reports app bar, with suggested questions, live progress ("consulting revenue…"), the four UI states, per-figure source sheet, copy answer / copy figures CSV. Conversation lives in the Cubit for the session only.
- Inert when `ANTHROPIC_API_KEY` is absent: the function answers `AiUnavailableError`, reserves no budget and the page shows a "not configured" state.
- Answers follow the app locale (`es` / `en`).

## Capabilities

### New Capabilities

- `report-assistant`: natural-language questions over the admin report RPCs — tool allowlist, structured verifiable answer, PII minimisation, prompt-injection stance, chat UI.
- `ai-platform`: shared plumbing for every Claude-backed Edge Function — API key handling and inert mode, per-lot daily budget, usage accounting, retention of the usage log.

### Modified Capabilities

<!-- none: the existing `reports` requirements are untouched; the assistant only reads through the same RPCs -->

## Impact

- **Database**: one new migration `<NEXT>_ai_usage.sql` (use the next free number at implementation time; current head is `0102`, `add-public-booking-captcha` holds `0103`). New tables `public.ai_requests`, `public.ai_limits`; new functions `ai_default_limit`, `ai_budget_status`, `ai_budget_reserve`, `ai_usage_record`, `set_ai_limit`, `purge_ai_requests`. No existing table, policy or RPC is altered.
- **Edge Functions**: new `supabase/volumes/functions/_shared/ai/*.ts`, new `supabase/volumes/functions/report-assistant/*.ts`, `supabase/volumes/functions/deno.jsonc` (import map entry for `@anthropic-ai/sdk`), `supabase/.gitignore` (allowlist), `supabase/docker-compose.yml` (`functions` service environment).
- **Flutter**: new `lib/features/report_assistant/`, `lib/app/di/modules/report_assistant_module.dart`, `lib/app/di/injection.dart`, `lib/app/router/deferred/report_assistant_entry.dart`, `lib/app/router/app_router.dart`, `lib/features/reports/presentation/reports_page.dart` (one app-bar action), `lib/core/l10n/failure_messages.dart`, `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb` (+ regenerated `app_localizations*.dart`).
- **Ops**: `.env.example` (new variables), `supabase/jobs.sh` and `supabase/notifications-cron.sh` (`purge_ai_requests`), `.github/workflows/ci.yml` (new `edge-functions` job running `deno test`).
- **Docs**: `CHANGELOG.md`, `docs/project-overview.md`, `docs/agent-memory.md`, `docs/database.md`, `docs/architecture.md`, `docs/runbook-secrets.md`.
- **Dependencies**: Edge runtime gains `npm:@anthropic-ai/sdk` (import map). No new Flutter package (`functions_client` 2.7.1, already resolved through `supabase_flutter`, returns a `ByteStream` for `text/event-stream`).
- **Third party**: question text and a field-allowlisted projection of report results are sent to the Claude API (Anthropic). See design § Security and privacy.
- **Breaking**: none.

## Non-Goals

- Text-to-SQL, or any tool that is not a registered read-only RPC.
- Writing anything (discounts, tariffs, sessions, settings) on the user's behalf.
- Questions about one vehicle, plate, owner, operator or audit entry (PII); the assistant redirects to the existing screens.
- Forecasts, anomaly detection or advice ("should I raise prices?").
- Server-side conversation history, cross-device history or a prompt library.
- Operators using the assistant.
- Token-by-token streaming of the answer text (see design, Decision 7).
- A settings UI for the daily budget (RPC only in v1).
