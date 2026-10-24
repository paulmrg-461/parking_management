# Agent memory

Durable context for any agent working on this repo. Read this first, then
`AGENTS.md` (rules) and `PROGRESS.md` (product history). Keep it short and
current: append decisions and gotchas, delete what the code now explains.

Last updated: 2026-10-23, branch `feature/supabase` (post-hardening).

## Where we are

- Stack: Flutter (android + web) + self-hosted Supabase only. No FastAPI,
  Alembic, Dio, Redis or `backend/` — never reintroduce them.
- `supabase/migrations/0001..0026` are the schema owner (applied by
  `supabase-migrate`); SQL RPCs own business logic; RLS everywhere.
- Flutter: 480 tests green, `flutter analyze` reports only SDK
  deprecation/const infos from the local beta channel (0 errors/warnings).
  Web build green. `supabase/tests/run.sh` green.
- OpenSpec: `openspec/changes/add-multi-parking-lot` is 24/25 done (only the
  header-fallback "contract" migration remains, intentionally later).

## What shipped recently

1. High priority: pass charges/payments, backup/restore scripts, real SQL CI.
2. Medium: pass-charge backfill (`0017`), audited shift corrections (`0018`),
   offline guards for cash/shift/pass collection, notification deep links,
   admin PIN reset/delete with last-admin/self-delete guards.
3. Low/product: lost ticket full daily tariff (`0019`), vehicle notes +
   admin-only blacklist (`0020`), capacity reservations and full-category
   pre-blocking (`0021`), localized printed receipts (`ReceiptLabels`),
   skeletons honoring reduce-motion, browser push (VAPID + service worker,
   `0022`).
4. Multi-lot: `0023` (lots, members, `lot_id` columns, unique keys),
   `0024` (`current_lot_id`, lot CRUD, re-scoped policies/RPCs/reports,
   `report_revenue_all`), `0025` (offline replay lot capture via
   `resolve_lot`), `0026` (`list_lot_members`).

## Invariants worth re-reading

- Active lot = `x-lot-id` header validated by `current_lot_id()` against
  `lot_members`; missing header falls back to the lowest membership. Client
  lot ids are only trusted through `resolve_lot()`.
- Queued mutations capture `lot_id` at enqueue time; replays land in the origi-
  nal site even after a lot switch.
- Lot-scoped Flutter caches are namespaced (`categories`, `tariffs`,
  `monthly_passes`, `notifications`, settings key `current_<lot>`, logo
  `<lot>_<version>`). Vehicles stay global (a plate can park anywhere).
- Receipts print the active lot's `parking_settings`; thermal labels come from
  `ReceiptLabels` (es/en), ASCII-only.
- Cash/shift actions are disabled offline with a banner and never queued.
- Auth: GoTrue only; `admin-users` Edge Function owns user CRUD and accepts
  `lot_id` (assigns membership, drops the seeded default lot when creating in
  another site).

## Documentation map

`docs/README.md` indexes the set: `setup-local.md`, `setup-cloud.md`,
`architecture.md`, `infrastructure.md`, `database.md`. Diagrams are Mermaid in
Markdown; update the diagram with the code change (new table → `database.md`,
new service/port → `infrastructure.md`, new flow → `architecture.md`).

## Commands

```bash
# Flutter
flutter test
flutter analyze
flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Local stack (repo root)
docker compose up -d                 # gateway/studio on :8000
docker compose up -d supabase-migrate && docker compose logs --tail=5 supabase-migrate
docker compose restart functions     # after editing supabase/volumes/functions

# SQL suite against a scratch database
PW=$(grep -E '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
docker exec supabase-db psql -U supabase_admin -d postgres -c "drop database if exists sql_test;"
docker exec supabase-db psql -U supabase_admin -d postgres -c "create database sql_test owner supabase_admin;"
docker run --rm --network parking_management_default -v "$PWD/supabase:/work" \
  -e PGHOST=supabase-db -e PGUSER=supabase_admin -e PGPASSWORD="$PW" -e PGDATABASE=sql_test \
  postgres:17-alpine sh -c "cd /work && sh tests/run.sh"

# Local admin login: admin / 123456 (6-digit PIN, email admin@parking.local)
```

## Gotchas learned the hard way

- `parking_settings.id` was a manual singleton; `0023` converts it to an
  identity column and calls `setval`, otherwise the second lot collides.
- Never name a PL/pgSQL variable `current_role` (SQL keyword): the `select into`
  silently ignores it. Use `existing_role`.
- PostgREST caches the schema: after adding an RPC, apply the migration and wait
  (or restart) before calling it, else `PGRST202`.
- `SupabaseClient.headers` is an unmodifiable getter plus a setter; assign a new
  map to change `x-lot-id` (there are no per-request headers in `rpc()`).
- `alter table ... add column lot_id integer not null default 1 references ...`
  backfills in one statement; that is how the lot migration stays reversible.
- `create or replace function` fails if the signature changed; drop the old
  signature explicitly (as `0025` does for check-in/check-out).
- Hive keys for lot-scoped caches are strings (`<lot>_<id>`), so no adapter
  regeneration is needed when the entity has no `lot_id`.
- Web push needs HTTPS (service-worker origin) and operator-provided VAPID/FCM
  credentials; without `WEB_PUSH_VAPID_PUBLIC_KEY` the inbox toggle is hidden.

## Hardening pass (latest)

- Branding is per lot: `0027` scopes `set_branding_logo` to the active lot,
  the client uploads `branding/logo_<lotId>`, and the shell/auth reload
  `BrandingCubit` on a lot switch.
- Evidence objects: `storage.objects` read policy now joins
  `evidence_photos` → `parking_sessions` and requires the active lot; a SQL
  regression guard asserts the policy mentions `current_lot_id`.
- CI runs on `feature/**` too; `.env.example` sets `PASSWORD_MIN_LENGTH=6` and
  `RATE_LIMIT_HEADER`, and the auth service passes `GOTRUE_RATE_LIMIT_HEADER`.
- `web/manifest.json`, `web/index.html` and the Android label no longer ship
  Flutter defaults.

## Operational batch (latest)

- PDF export: `buildRevenueReportPdf` (reports, includes the per-site
  breakdown) and `buildShiftPdf` (arqueo) share through `printing`;
  `sharePdfBytes` / `pdfFileName` live in `core/receipt/pdf_share.dart`.
- Shift history filters: `list_shifts(p_limit, p_start_date, p_end_date)` (lot
  implicit) + a date-range picker in the admin history; clearing is explicit.
- Retention (`0028`): `expire_reservations`, `purge_stale_notifications` and the
  existing idempotency purge, all called by `notifications-cron.sh`. pg_cron is
  NOT available in this image's `parking` database (it can only be installed in
  `postgres`), so scheduling stays in the host cron; the README documents how
  to enable pg_cron if the deployment supports `cron.database_name`.

## Automated WhatsApp (latest)

- `0042`: `parking_settings.whatsapp_auto` + `whatsapp_messages` (pending/sent/
  failed, attempts, error, lot) and `enqueue_whatsapp_message` (operators; only
  when the site enabled the flag), `purge_whatsapp_messages(90)` in the cron.
- `whatsapp-dispatch` (service-role) sends Meta templates `receipt`/`pass_expiry`
  with positional body params; retries 3 times. No credentials → `configured:false`.
- App: `BrandingCubit.settingsOrNull.whatsappAuto` decides between enqueue
  (`whatsappQueued` snack) and `wa.me`; `CustomerMessageRepository` is the port.
- Passes/history UI tests cover both branches (fake repo + branding).
- `/diagnostics` shows the queue (pending/failed/sent 24 h) and the recent
  messages; `healthcheck.sh` warns on failed ones; `diagnostics.sql` has a
  matching section.

## WhatsApp receipts (latest)

- `0041`: `vehicles.owner_phone` (+ check 7–15 digits) and
  `update_vehicle_flags(plate, blacklisted, notes, owner_phone)` (old 3-arg
  signature dropped); `vehicle_history` returns `owner_phone`.
- History: phone chip (opens a greeting) or "Add phone"; closed sessions have a
  chat icon that builds `receiptWhatsappMessage` and opens `wa.me` with text.
- `whatsappUrl(raw, text:)` encodes the message; launching failures show a snack.
- Pass expiry: `Vehicle.ownerPhone` reaches the passes list (vehicles are
  loaded there); active passes with a phone offer a reminder built by
  `monthlyPassWhatsappMessage`. Launching lives in
  `core/utils/whatsapp_launcher.dart` (shared with the history).

## Ticket reprint (latest)

- `0040`: `vehicle_history` sessions include `discount_amount`/`discount_reason`
  so a reprint matches the original receipt.
- The history tile has a receipt icon (closed sessions with a ticket) that
  opens `showReceiptSummary` with a `ReceiptData` rebuilt from the session and
  the print sheet as `onPrint`.

## Site comparison (latest)

- `0039`: `report_revenue_all` by_lot now includes `tickets` and `avg_ticket`
  and lists every lot via `left join` (zero-revenue sites included).
- `LotComparison` widget (reports) sorts by revenue and shows a bar, the
  percentage of the total and `N exits · average X`; only in consolidated mode.

## WhatsApp round-out (latest)

- `vehicle_ready` template (params: plate) + an action on open sessions with a
  phone; dispatch maps `WHATSAPP_TEMPLATE_READY`.
- `0044`: `report_whatsapp(start, end)` (admin, active lot) with sent/failed/
  pending and by-day; the reports page shows it when there is data.
- Analyzer baseline: 0 non-deprecation infos; the ~112 remaining are SDK
  `deprecated_member_use` from the pinned beta channel.

## Secrets runbook (latest)

- `supabase/rotate-pin.sh <user> <pin>`: GoTrue admin API with the service key
  (works with no signed-in admin); no audit row — log it manually.
- `supabase/check-secrets.sh`: `.env` mode/placeholders/tracked/`DISABLE_SIGNUP`/
  `PASSWORD_MIN_LENGTH`, exits 1 on failures.
- `docs/runbook-secrets.md`: inventory, quarterly review, PIN/JWT/DB/provider
  rotation (JWT rotation logs everyone out and needs client rebuilds; DB needs
  `ALTER USER` for postgres, supabase_admin, supabase_auth_admin,
  supabase_storage_admin, authenticator) and leak response.

## Restore drill (latest)

- `supabase/restore-drill.sh [backups/<stamp>]`: creates a scratch DB, restores
  with `pg_restore -U supabase_admin --no-owner` (as `postgres` every ACL fails
  — this was a real bug in `restore.sh`, now fixed), compares
  schema_migrations, core RPCs, RLS policy count, `authenticated` grants, row
  counts and the storage tar, then drops the scratch DB.
- `docs/runbook-restore.md`: monthly drill, production restore, new-host
  recovery (keep JWT keys or devices must log in again), rollback and cadence.
- CI's `supabase-e2e` job runs backup + drill, so the dump is exercised on
  every push.

## Product polish (latest)

- Vehicle history: sessions carry `lotId`/`lotName`; the page shows a site chip
  per session and filters locally by site (no extra RPC).
- Home: `dashboard_today()` (active lot, business-timezone midnight) feeds a
  `TodayCard` (revenue/cash/pass/entries/exits). A failing summary degrades to
  zeros instead of hiding occupancy.

## Audit export (latest)

- `0037`: `list_audit_log(limit, start, end, table, actor)` (actor = username,
  case-insensitive) dropped/recreated — PostgREST needs the migration applied.
- `/audit` exports the visible page as PDF (`buildAuditPdf`) or CSV
  (`auditCsv`, copied to the clipboard); actor dropdown derives from the
  loaded page.

## Admin diagnostics (latest)

- `0036`: `diagnostics_snapshot()` (admin) returns counters + storage usage;
  `list_client_error_reports(limit, days)` lists the reported errors.
- Flutter `/diagnostics` (admin nav) renders both; the SQL suite bootstraps
  `schema_migrations` and `storage.objects.metadata` so the snapshot works in
  tests.
- `supabase/diagnostics.sh` remains the shell equivalent; keep counters in sync.

## Evidence retention (latest)

- `0033`: `parking_settings.evidence_retention_days` (0 = keep, ≤3650) + UI
  field in settings.
- `evidence-archive` Edge Function (service-role only, `days=`/`dry_run=`
  params) deletes the Storage object then the row; cron script
  `supabase/evidence-archive.sh` runs daily after the backup.
- `0034`/`0035`: Storage cannot forward `x-lot-id`, so `can_read_evidence(path)`
  (security definer) checks membership instead of `current_lot_id()`. The
  first version returned 500 on downloads — keep the helper.
- Storage answers DELETE on a missing object with 400 + `NoSuchKey`; treat it as
  already deleted.

## Multi-lot contract (latest)

- `0032`: `x-lot-id` is mandatory; missing/forged → `LotRequiredError`. The
  Flutter `AuthCubit` awaits `onSessionReady` (lots loaded → header set) before
  exposing the authenticated state. `notify_overstays` no longer uses
  `current_lot_id()` (per-lot threshold/timezone, all sites), so cron is safe.
- OpenSpec change archived: `openspec/changes/archive/2026-10-23-add-multi-parking-lot`,
  capability `openspec/specs/parking-lots`.
- E2E suites send the header; `supabase/tests/rpc_test.sql` sets lot 1 at the
  top and switches per block.

## E2E (latest)

- `supabase/tests/e2e.sh`: curl-level flow (login → check-in → check-out →
  report → history) with `E2E…` plates; used by the `supabase-e2e` CI job and
  for post-deploy smoke tests.
- `test/integration/supabase_flow_test.dart`: same flow through the pure-Dart
  `supabase` client (dev_dependency). Skipped unless `SUPABASE_URL` and
  `SUPABASE_ANON_KEY` are set; the CI job exports them from `.env`.
- Both fail on: session not open, wrong lot, ticket without `TCK-`, report total
  below the charge, empty history.

## Admin audit (latest)

- `0031`: `audit_log` + `record_audit()` trigger (categories, tariffs, vehicles,
  monthly passes, settings, lots, lot_members). Updates store only the changed
  columns; `pin_hash` is stripped; `lot_id` comes from the row.
- `admin-users` writes explicit audit rows (service-role writes have no
  `auth.uid()`), including `pin_reset: true` without the PIN itself.
- Read model `list_audit_log(limit, start, end, table)` (platform admins) backs
  the Flutter `/audit` screen; `purge_audit_log(365)` runs in the cron.

## Observability (latest)

- `0030`: `client_error_reports` + `report_client_error` (bounded payload,
  actor from auth.uid(), admin read) + `purge_client_error_reports(30)` in the
  cron.
- Flutter: `ErrorReporter` (throttled/deduped, disabled in debug) with a
  Supabase sink, installed in `main.dart` for `FlutterError.onError` and
  `PlatformDispatcher.onError`.
- Functions: JSON log line per request; `docker compose logs functions`.
- Ops: `healthcheck.sh` (exit 1 on failure, `HEALTHCHECK_WEBHOOK` alerts) and
  `diagnostics.sh` (stuck sessions/shifts, backlog, client errors, sizes).

## Backlog / next moves

- `5.4` contract migration: drop the missing-header fallback once every client
  sends `x-lot-id`.
- Optional polish: per-lot receipt footer beyond settings, lot filter on the
  vehicle history UI, audit-log export, admin diagnostics screen.
- Dev DB artifacts from smoke tests: lot `NORTH` ("Sede Norte") and user
  `norte2` (operator, PIN `123456`, member of lot 2). Safe to delete.
