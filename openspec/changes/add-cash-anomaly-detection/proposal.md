## Why

Cash and operator control is manual today. The only signals an admin gets are the "Cierre de turno" notification with the cash difference (`close_shift`, `0073`), the overstay alert (`notify_overstays`, `0032`) and whatever they find by browsing `/shift`, `/records` and `/audit`. Nobody is told that the same operator closed three shifts short in two weeks, that one cashier's lost-ticket rate is four times the lot's, or that a "lost ticket" was charged on a 4-minute stay. These are the standard leak patterns in a cash business, and every datum needed to detect them is already in the database.

## What Changes

- **Eight deterministic SQL rules** (no ML), each with exact thresholds, a severity and a dedup key: repeated shift shortages per operator, lost-ticket rate per operator vs the lot baseline, shift adjustments made after close, zero-amount check-outs that are not passes, lost-ticket charges on very short stays, discount share per admin, shifts left open too long, sessions open beyond N days.
- **New tables:** `cash_anomalies` (one row per detected anomaly, status `open` / `acknowledged` / `dismissed`, unique per `(lot_id, dedupe_key)` so nothing is raised twice) and `anomaly_settings` (per-lot thresholds with defaults and range checks; a separate table so operators, who can read `parking_settings`, cannot read the thresholds). Both are admin-only through RLS.
- **Scheduled detection:** `public.detect_cash_anomalies()` and `public.purge_cash_anomalies(p_days)` run from `supabase/jobs.sh` (the `supabase-jobs` container, every `JOBS_INTERVAL_SECONDS`, default 300 s; pg_cron is unavailable) and from `supabase/notifications-cron.sh`.
- **Delivery:** one summary notification per lot per run, type `cash_anomaly`, to the lot's active admins only, through the existing `notifications` table (dedupe key, realtime, push) with a deep link to `/anomalies`.
- **RPCs (admin only):** `list_cash_anomalies`, `resolve_cash_anomaly` (acknowledge or dismiss, with a note; a dismissal requires one), `get_anomaly_settings`, `set_anomaly_settings`.
- **Audit:** `cash_anomalies` and `anomaly_settings` get the existing `record_audit()` trigger, so every acknowledge, dismissal and threshold change is in `audit_log` with the actor.
- **Flutter:** new feature `lib/features/anomalies` with an admin-only "Anomalías" page (list, filters by status, rule and severity, acknowledge/dismiss with note, threshold sheet, links to the audit trail, the shift list and the vehicle history), a nav entry, notification label/icon/deep link, and `AuditPage` accepting an initial table/search so the link lands filtered.
- **Extension point for later changes:** `public.anomaly_zero_charge_excluded(p_session_id integer)` returns `false` today; `add-loyalty-rewards` and `add-merchant-validations` redefine it so a legitimate free exit is not flagged. The rules work without them.

## Capabilities

### New Capabilities

- `cash-anomalies`: the rule set, thresholds, severities, dedup, scheduling, review workflow, settings, audit and role isolation.

### Modified Capabilities

- `notifications`: adds the admin-only `cash_anomaly` alert with a deep link.

## Impact

- **Database:** one migration, `<NEXT>_cash_anomalies.sql` (use the next free number at implementation time; it must come after `<NEXT>_report_period_comparison.sql` of `add-period-comparison-reports`, whose index `ix_sessions_lot_exit_closed` it also declares with `if not exists`). Tests in `supabase/tests/rpc_test.sql`.
- **Ops:** `supabase/jobs.sh` (two `run` lines), `supabase/notifications-cron.sh` (two `psql` lines). No compose change: `jobs.sh` is mounted read-only (`./supabase/jobs.sh:/jobs.sh:ro`); `docker compose restart supabase-jobs` after the edit.
- **Flutter:** `lib/features/anomalies/**`, `lib/app/di/modules/anomalies_module.dart`, `lib/app/di/injection.dart`, `lib/app/router/app_router.dart`, `lib/app/shell/app_destinations.dart`, `lib/features/audit/presentation/audit_page.dart`, `lib/features/notifications/presentation/notification_routes.dart`, `lib/features/notifications/presentation/notifications_page.dart`, `lib/core/l10n/failure_messages.dart`, ARB files.
- **Docs:** `CHANGELOG.md`, `docs/project-overview.md`, `docs/database.md`, `docs/agent-memory.md`.
- **Breaking:** none. `/anomalies` is not in `operatorRoutes` (admin-only by default).

## Non-Goals

- Machine learning, scoring models or cross-lot benchmarking.
- Blocking or reversing any transaction: the feature only observes and reports.
- Voids: the system has no void/cancel-sale operation to monitor (see `design.md` §Findings); adjustments after close are the only post-hoc correction and are covered.
- Operator-facing views of any kind.
- Detection on offline queues: only committed rows are evaluated.
- Per-user (rather than per-lot) thresholds.
