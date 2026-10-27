# Agent memory

Durable context for any agent working on this repo. Read this first, then
`AGENTS.md` (rules) and `PROGRESS.md` (product history). Keep it short and
current: append decisions and gotchas, delete what the code now explains.

Last updated: 2026-10-26, branch `feature/supabase` (post-UI/UX polish).

## Where we are

- Stack: Flutter (android + web) + self-hosted Supabase only. No FastAPI,
  Alembic, Dio, Redis or `backend/` — never reintroduce them.
- `supabase/migrations/0001..0046` are the schema owner (applied by
  `supabase-migrate`); SQL RPCs own business logic; RLS everywhere.
- Flutter: 646 tests green, `flutter analyze` reports only SDK deprecation
  infos from the pinned beta channel (0 errors/warnings). Web build green.
  `supabase/tests/run.sh` and `supabase/tests/e2e.sh` green.
- OpenSpec: multi-lot archived (`openspec/specs/parking-lots`); the only open
  item is the manual smoke for `add-parking-settings` (task 10.4).

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

`docs/README.md` indexes the set: `project-overview.md` (executive summary),
`environment-guide.en.md` / `environment-guide.md` (onboarding, EN/ES),
`setup-local.md`, `setup-cloud.md`, `architecture.md`, `infrastructure.md`,
`database.md`; root `QUICKSTART.md` (commands) and `CHANGELOG.md` (changes +
migration history). Diagrams are Mermaid in
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

## UI/UX polish (latest)

- `core/utils/elapsed.dart`: `elapsedLabel` / `isLongStay` (24 h) feed check-out
  and check-in lists; check-out shows a "Más de 24 h" warning chip.
- Monthly passes: `monthlyPassStatus` + `sortMonthlyPasses` (active → upcoming →
  expired, soonest first) and a status chip in the tile.
- `EmptyState` is now used by reservations, lots and audit lists; the home
  "today" card has a quiet-day message when every counter is zero.
- Vehicles: `listPage(plate:)` filters server-side (`ilike`), the cubit debounces
  `search()` and keeps the term across refreshes; the list has a no-match state.
- Reports: segmented presets (Today / 7 / 30 days) next to the calendar; a custom
  range clears the preset. Tests must pass the vertical `Scrollable` explicitly
  (the preset row adds a second one).
- `showReceiptSummary(..., nextActionLabel, onNextAction)` adds a "keep
  working" button (closes the dialog then runs the callback). Check-out uses it
  with `resetActiveSearchField()` (clears + refocuses the visible field).
- `core/widgets/search_field.dart`: shared search input (autofocus only on
  web/desktop so mobile keyboards do not pop up, clear button, `Esc` resets);
  used by vehicles and check-out. The last mounted field registers itself as
  `_activeSearchFocus`; `SearchShortcuts` (wraps `MaterialApp.router`) binds
  Ctrl/Cmd+K to `focusActiveSearchField()` through a `HardwareKeyboard`
  handler, so the shortcut works regardless of focus. Success handlers call `SemanticsService.announce`
  in addition to the snack/dialog.
- Check-in stores `last_plate` in `KeyValueStore` (box `preferences`) after a
  success and offers a repeat chip; guarded by `serviceLocator.isRegistered`
  so page tests can skip it or inject a fake store.
- The shift close dialog result is checked against `expectedCash`; a mismatch
  goes through `ConfirmDialog` (destructive) before `closeShift` is called.
- `ShiftCubit._submit` emits `SubmissionSucceeded(shift)` + `lastAction`
  (`opened/closed/movement/adjusted`) after a confirmed cash action; the page
  announces it and shows an info snack. Do not revert it to `SubmissionIdle`,
  the confirmation depends on the transition.
- The occupancy bar animates through `TweenAnimationBuilder` only when
  `MediaQuery.disableAnimationsOf` is false (same rule as `StaggeredListItem`
  and the skeleton loaders).
- `core/widgets/staggered_list_item.dart` wraps list rows (vehicles,
  reservations) with a one-shot fade+slide keyed by the row id; it renders the
  bare child when `MediaQuery.disableAnimationsOf` is true.
- `core/widgets/plate_input_field.dart` is the single plate input (check-in,
  reservation dialog, vehicle creation): its formatter uppercases and strips
  blanks live and caps at 20, the column width. Do not add another formatter.
- `LotSwitcher` (formerly `LotBar`) is a chip inside the home content on narrow
  screens only; wide screens use `AppSidebar`'s footer (same bottom sheet via
  `showLotSwitcher`). The old shell strip was removed.
- `AppSidebar` (wide shell, ≥900 px): brand + role, Operación/Gestión groups,
  active-site and user footer, and a collapse toggle persisted at
  `preferences/sidebar_collapsed` (264 → 84 px). Content max width is 1080.
  The home app bar titles itself "Inicio" on wide screens (brand lives in the
  sidebar) and the home hides `ManagementShortcuts` there (they are in the
  sidebar); mobile keeps both. The sidebar clips while it animates.
- `ThemeCubit` (`preferences/theme_mode`, system/light/dark) is optional in
  `ParkingApp` so tests stay on the system theme; `ThemeModeButton` lives in the
  home app bar and is hidden when the cubit is not provided.
- `VehiclesCubit.create` reports `SubmissionSucceeded(vehicle)` (update/delete
  stay idle); the page shows a snack with a "Registrar entrada" action that
  pushes `/check-in?plate=` (`onCheckIn` is injectable for widget tests).
- `MonthlyPassesCubit` reports `lastAction` (`created/deleted/payment`) and the
  page confirms it; `update` (activation toggle) stays idle on purpose because
  that tile shows an undo snack. `ReservationsCubit` does the same with
  `created/cancelled`.
- Monthly passes: the page filters passes and pending payments client-side by
  plate (`plateOf`), with `monthlyPassesNoMatch` when nothing matches.
- Users list filters client-side by role with a `SegmentedButton`; the empty
  filtered result uses `EmptyState` (`usersFilterEmpty`), never the "no users"
  message.
- `CheckOutPage(initialQuery:)` + `SearchField(initialValue:)` prefill and
  filter the check-out list from `/check-out?plate=`; the vehicle history sends
  open sessions there (`onCharge` is injectable for widget tests).
- Check-in compares the typed plate (normalized) with `CheckInState.sessions`
  and shows a non-blocking warning (`checkInAlreadyInside`); the submit stays
  enabled because the local list may be stale.
- `CheckInPage(initialPlate:)` prefills the field and runs the lookup on the
  first frame; the router reads it from `/check-in?plate=`. Reservations pass
  their plate to it (`onCheckIn` is injectable for widget tests).
- Reservations: `Reservation.expiresSoon({now, window})` (default 2 h,
  expired holds excluded) drives a warning chip; `sortedByExpiry` returns a new
  soonest-first list used by the page (never sorts the state list in place).
- `0046` rewrites `open_sessions_view` with `has_pass` (same pass rule as the
  preview, lot timezone via a lateral settings join). The list shows a
  "Mensualidad" chip so the car is known to be free before the dialog.
- Check-out stores `last_payment_method` in `KeyValueStore` (box
  `preferences`) only after the server confirms; `_SessionTile` receives the
  remembered method and falls back to cash when it is `monthly_pass` or the
  preview has no pass.
- `reportCsv` (reports) emits `section,label,value` rows with raw numbers and
  RFC 4180 quoting; the page copies it to the clipboard (audit already does the
  same for its own CSV).
- `reportComparisonRows` builds the PDF comparison lines (variation + previous
  total) and returns them empty when the previous window is unknown; the page
  passes `previousTotal`/`deltaPercent` to `buildRevenueReportPdf`.
- Reports load the previous, equally long window in the same `Future.wait`
  (`onError: null`); `ReportsLoaded.previousTotal/deltaPercent` drive the
  `_DeltaRow`. A failed previous window degrades to no delta, never an error.
- `0045` `check_out_preview(session)`: same `calculate_fare` as check-out,
  read-only; the checkout dialog shows the estimate (or pass coverage). The
  cubit returns `null` on a failed preview so the dialog still opens.

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

## Dev environment running (2026-10-26)

- Backend: `docker compose up -d` from the repo root; all services healthy,
  gateway/Studio on <http://localhost:8000>; migrations up to date.
- Flutter web: `flutter run -d chrome --dart-define=SUPABASE_URL=http://localhost:8000
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>` (log: `/tmp/opencode/flutter-web.log`).
- Android (Samsung S901E over wireless adb): `sh tool/run-android.sh` — it
  re-applies `adb reverse` and runs with `SUPABASE_URL=http://localhost:8000`.
  Install-only alternative: `flutter build apk --debug --dart-define=...` then
  `adb install -r ... && adb shell am start -n
  pro.devpaul.parking_management/.MainActivity`.
- Login: `admin` / `123456`. Dev data: lot 1 "Parqueadero" (categories + data)
  and lot 2 "Sede Norte" (member `norte2`, **no categories**: a new vehicle
  cannot be registered there until categories/tariffs are created).
- The apps use `localhost:8000`; if the phone shows "cannot reach the server",
  check `adb reverse --list` first (see below), not `ufw`.

## Android over adb

- `tool/run-android.sh [serial]` re-applies `adb reverse tcp:8000 tcp:8000` and
  runs Flutter with `SUPABASE_URL=http://localhost:8000`. **Wireless adb
  reconnects on a new port and drops every reverse mapping** — the app then
  cannot reach the backend until the reverse is re-applied. No `ufw` rule is
  involved on that path; only a LAN URL needs `ufw allow 8000/tcp`.
- `adb shell curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/rest/v1/`
  must answer `401` (reachable); `000` means the tunnel is missing.

## Boot order (fresh installs)

- `configureDependencies()` initializes `KeyValueStore` (Hive) **before**
  `_initSupabase`: the boot clears a stale cached session through Hive, which
  needs `Hive.init(path)` on mobile (web needs no path, so the bug only showed
  on a fresh Android install).
- Android over adb: `adb reverse tcp:8000 tcp:8000` + `SUPABASE_URL=
  http://localhost:8000`; no firewall/Wi-Fi involved. Both are documented in
  QUICKSTART and the environment guides.

## Receipt QR / check-out scanning

- The QR payload is the **plate** (`Barcode.qrCode()` in `core/widgets/qr_code.dart`),
  printed on the **entry** receipt (screen, PDF via `pw.BarcodeWidget`, thermal
  via `GS ( k`) and captioned with `ReceiptLabels.scanHint`. Check-out receipts
  carry no QR: the car is already gone.
- `QrDecoder` (`core/qr/qr_decoder.dart`, zxing2 + image, pure Dart) decodes a
  camera capture; `plateFromQrPayload` accepts a bare plate or `?plate=`/`?p=`
  and rejects anything else (a random QR cannot start a check-out).
- Check-out: `resolvePlate` asks the server for the exact plate (limit 2, only a
  single match opens); `_startCheckout` moved from the tile to the page so the
  scan and a USB reader's `Enter` (`SearchField.onSubmitted`) reuse it.
- The camera button only renders when the route injects `capture` + `qrDecoder`;
  the search field still works with a keyboard-wedge reader alone.

## Branding assets

- `assets/branding/logo.png` is the app mark; `tool/generate_branding.py`
  regenerates it plus the Android mipmaps, web icons/favicon and maskable
  variants (deterministic, Pillow). The login header uses the per-lot logo when
  `BrandingCubit.logoOrNull` has bytes, else this asset, else the parking icon.
- `web/manifest.json`/`index.html` use the asphalt background (`#0B0D10`);
  keep them in sync if the mark changes.

## Evidence uploads

- Storage evidence is **insert-only** from the client: the SELECT policy uses
  `can_read_evidence(name)`, which is true only after `check_in` inserts the
  `evidence_photos` row. `upsert: true` therefore fails (INSERT ... ON CONFLICT
  needs to read the row) with a misleading "permission" error.
- `isDuplicateUpload` treats storage `409`/`Duplicate` as success: a replay of
  the same queued entry already stored that exact path. Never swallow 403.
- Verified against the live stack: insert 200 → duplicate 409 → `check_in` with
  the photo path returns `photo_count: 1`.

## Latest verification (2026-10-26)

- `flutter test`: 646 passed (+1 live-stack integration skipped); `flutter
  analyze` 129 infos, all SDK `deprecated_member_use` (zero warnings/errors);
  `flutter build web --release` OK.
- `supabase/tests/run.sh` passed (migrations `0001`–`0046`); `e2e.sh` passed
  (login → check-in → check-out → report → history).
- `healthcheck.sh`: 0 failures (one warning for a dev shift left open >12 h).
- UI/UX batches landed this session: reports comparison (screen, PDF, CSV),
  remember payment method, shift confirmations + mismatch guard, Ctrl/Cmd+K,
  reservations expiry chip + jump to check-in, continuous "Nuevo cobro",
  shared plate input, staggered rows, users role filter, passes plate search,
  monthly-pass chip on check-out, device appearance, the "already inside"
  check-in warning, the app mark/launcher icons, the site switcher moved from a
  shell strip into a compact home chip, reservation quick-hold chips (+2 h,
  +4 h, end of day), one-tap 30-day renewal for expiring monthly passes, and
  first-action buttons inside empty lists (users, vehicles, passes), and a
  discard-changes guard on the settings form, and an empty/no-match state on
  check-out with a "clear search" action, and a web-style collapsible sidebar
  (grouped sections, site + user footer, collapse persisted), and a receipt QR
  that opens check-out from the camera or a USB scanner.
- Hardware run found and fixed two boot bugs: Hive now initializes before the
  Supabase session cleanup, and evidence uploads are insert-only (see above).
- Current HEAD after the polish: `21f0149` (site switcher) on top of
  `dece16c` (branding) and `9d4225e` (run-android helper).

## Backlog / next moves

- `5.4` contract migration: drop the missing-header fallback once every client
  sends `x-lot-id`.
- Optional polish: per-lot receipt footer beyond settings, audit free-text
  search, configurable shifts; the lot switcher could later live in an app-bar
  menu instead of the home chip.
- Dev DB artifacts from smoke tests: lot `NORTH` ("Sede Norte", no categories)
  and user `norte2` (operator, PIN `123456`, member of lot 2). Safe to delete.
- Closed dev sessions from probing (`PERMTEST1`, `PHOTOE2E`) were checked out and
  are only history rows; storage probes were test artifacts.
