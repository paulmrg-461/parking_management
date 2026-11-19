## Why

Disputes over scratches and dents are the most expensive conversation at the gate. The app already stores entry evidence (`evidence_photos` rows plus objects in the `evidence` bucket, shown by `SessionEvidenceSheet`), but nothing is captured when the vehicle leaves, so there is nothing to compare against and every claim is settled by memory. This change adds an optional set of **exit photos** at check-out and an **advisory** comparison of the entry and exit photos by a Claude vision model, so the operator gets a short "possible new damage — verify" list with the photos side by side. A human always decides; nothing is charged, blamed or blocked automatically.

## What Changes

- Exit photos: new optional capture in the check-out dialog (reusing `PlateImageCapture`/`ImagePickerPlateCapture` compression, `EvidencePolicy` limits and the insert-only upload rule). New column `evidence_photos.phase` (`'entry' | 'exit'`, default `'entry'`) and new RPC `add_exit_evidence(p_session_id integer, p_photos jsonb)`. The existing `check_out(...)` signature is **not** touched.
- Guided capture: a guidance sheet and angle-slot chips (front-left, front-right, rear-right, rear-left, detail) shown before each capture, at both check-in and check-out, so the two sets are comparable. UI only; `check_in(...)` is not touched.
- Edge Function `damage-compare` (`supabase/volumes/functions/damage-compare/`): loads both photo sets with the caller's JWT (no service key for reading), downscales through Storage image rendering, sends them to Claude vision with a strict structured-output schema, validates and sanitises the result in code (downgrades unsupported "new" claims to "uncertain", computes the overall verdict itself), and stores it with a service-role-only RPC so an operator cannot forge an AI result.
- New tables `damage_comparisons` and `damage_findings` (lot-scoped, RLS, written only through RPCs), RPCs `begin_damage_comparison`, `store_damage_comparison`, `fail_damage_comparison`, `get_damage_comparison`, `review_damage_finding`, `purge_damage_comparisons`.
- Review workflow: the operator confirms or dismisses each finding with a mandatory note; the change is audited through the existing `record_audit()` trigger. Admins can re-run a comparison; operators get one run per session.
- Flutter: new feature `lib/features/damage_comparison/` (domain, application Cubit, infrastructure, presentation: side-by-side page, finding cards with review actions, "advisory" banner), extensions to `lib/features/evidence` (entry/exit grouping), `lib/features/check_out` (exit photo section) and `lib/features/check_in` (guidance only).
- Cost controls: image downscale to 1024 px long edge, at most 5 + 5 images, per-lot daily budget through the shared AI platform (feature `damage_compare`), result cached per session run.
- Retention: comparisons are deleted with the same per-lot `evidence_retention_days` window as the photos.
- Inert when `ANTHROPIC_API_KEY` is absent (exit photos and manual review still work).

## Capabilities

### New Capabilities

- `damage-comparison`: exit evidence, AI-assisted advisory comparison, review/audit workflow, privacy and accuracy limits.

### Modified Capabilities

- `check-out`: optional exit photos captured with the check-out and stored as evidence.
- `check-in`: guided photo capture so entry photos follow a standard set of angles.

## Impact

- **Depends on** `add-report-assistant`, which creates the shared helper `supabase/volumes/functions/_shared/ai/*` and the accounting tables `ai_features`, `ai_limits`, `ai_requests` with `ai_budget_reserve`, `ai_usage_record`, `ai_budget_status`. This change only adds one row to `ai_features` and imports the helper; it must be implemented after `add-report-assistant` (global order: … → add-bay-sensors → add-report-assistant → add-ai-damage-comparison).
- **Database**: one migration `<NEXT>_damage_comparison.sql` (use the next free number at implementation time; it must sort after `<NEXT>_ai_usage.sql`). Alters `evidence_photos` (additive column + index), adds the two tables, seven functions, one `ai_features` seed row. No existing function is redefined.
- **Edge Functions**: new `supabase/volumes/functions/damage-compare/`; `supabase/.gitignore` allowlist; `supabase/docker-compose.yml` (`functions` environment: `ANTHROPIC_MODEL_DAMAGE_COMPARE`, `AI_DAMAGE_*`, `SUPABASE_SERVICE_ROLE_KEY` already present).
- **Flutter**: new `lib/features/damage_comparison/`, `lib/app/di/modules/damage_comparison_module.dart`, `lib/app/di/injection.dart`, `lib/features/evidence/**` (entity `phase`, sheet grouping), `lib/features/check_out/presentation/payment_method_dialog.dart` and `check_out_page.dart`, `lib/features/check_in/presentation/check_in_page.dart` (guidance), `lib/core/network/supabase_error_mapper.dart`, `lib/core/l10n/failure_messages.dart`, ARB files.
- **Ops/docs**: `.env.example`, `docs/runbook-secrets.md`, `docs/database.md`, `docs/architecture.md`, `docs/project-overview.md`, `docs/agent-memory.md`, `CHANGELOG.md`, `supabase/jobs.sh`, `supabase/notifications-cron.sh`, CI `edge-functions` job (created by `add-report-assistant`).
- **Third party**: vehicle photos (which can show plates, people and surroundings) are sent to Anthropic when a comparison is run. See design § Privacy.
- **Breaking**: none. Existing `photo_count` values (`vehicle_history`, `session_records`, `open_sessions_view`) count every `evidence_photos` row and therefore start including exit photos; this is intended (they are "evidence files").

## Non-Goals

- Automatic charging, discounts, blocking check-out, notifying customers or flagging a vehicle as damaged.
- A legal-grade damage verdict or a replacement for a human inspection; no numeric damage estimates or repair costs.
- Video comparison (videos are never sent to the model).
- Live in-camera overlays (the `camera` package is not used by the app today); v1 uses a guidance sheet before the system camera opens.
- Queuing exit photos offline (v1 requires connectivity; see design Decision 6).
- Running comparisons automatically on every check-out.
- Comparing across sessions or vehicles.
