# Agent memory

Durable context for any agent working on this repo. Read this first, then
`AGENTS.md` (rules) and `PROGRESS.md` (product history). Keep it short and
current: append decisions and gotchas, delete what the code now explains.

Last updated: 2026-10-28, branch `feature/supabase` (UI kit pass, COP/USD
currency, es/en language, records exports).

## Where we are

- Stack: Flutter (android + web) + self-hosted Supabase only. No FastAPI,
  Alembic, Dio, Redis or `backend/` — never reintroduce them.
- `supabase/migrations/0001..0068` are the schema owner (applied by
  `supabase-migrate`); SQL RPCs own business logic; RLS everywhere.
- Flutter: 815 tests green, `flutter analyze` reports only SDK deprecation
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

## UI kit pass (2026-10-28)

- New shared widgets, documented in [`docs/ui-kit.md`](ui-kit.md): `SectionHeader`
  (icon chip + title/subtitle + trailing action), `MetricCard` (label, tabular
  value, caption, tonal icon, 48 dp when tappable), `FilterBar` (search/filters
  card with summary + clear action), `SkeletonCardList`/`SkeletonTable` next to
  `SkeletonList`, and stronger `EmptyState`/`ErrorState` (title + tinted icon +
  explicit CTA/retry). `AsyncEmpty` now forwards an optional `title`.
- Rules: no private `_SectionHeader` clones; list screens put search+filters in
  `FilterBar` and keep the count in its `summary`; pages use a skeleton that
  matches the geometry (rows, cards or table); empty states always offer the
  next step; errors only show localized messages with retry.
- Module changes: notifications grouped by day with an unread filter + CTA;
  audit has a filter card, action chips and a before → after field dialog; users
  gain search, initials avatars and role chips; records moved exports to one
  menu and filters into a card; home has quick-action tiles; vehicle history
  uses metric cards; shifts/spots/check-in use card skeletons and empty states;
  settings reuses `SectionHeader`.
- Currency labels no longer hardcode COP (`Valor`, `Descuento`, `Base inicial`);
  the symbol comes from `Money`.
- Gotcha: a lazily built `ListView` only builds visible children, so tests that
  assert the last row must use a tall viewport or scroll before asserting.

- **Sidebar (2026-10-28)**: tonal logo mark + role dot, gradient surface,
  rounded nav pills with accent bar, management accordion with count badge and
  indented guide line, site card and user card with online dot. Keys/tooltips
  and the persisted `sidebar_collapsed`/`sidebar_management_open` preferences
  are unchanged (shell tests depend on them).
- **Login and sparse screens (2026-10-28)**: the sign-in page splits into a
  brand panel + form card from `Layout.railBreakpoint` (and ≥ 560 px tall),
  keeps the PIN obscured with an eye toggle, renders failures as an inline
  error banner (live region) and shows language/theme only when those cubits
  are provided (tests omit them). Reservations and monthly passes now open with
  metric cards, a `FilterBar` (search + state chip), section headers and an
  empty state with the create/clear CTA; categories and tariffs do the same.
  `debugShowCheckedModeBanner` is off, so dev builds no longer show the banner.

## Currency and language (2026-10-28)

- **Currency** (`0068`): `parking_settings.currency` (`COP` default, `USD`,
  check constraint); `public_lot_profile` exposes it. Amounts stay integers in
  the currency **minor unit** (COP pesos, USD cents) — never floats, never a
  second column. `Money` (`core/money`) is ambient: `BrandingCubit` calls
  `Money.configure(Currency.fromCode(settings.currency))` on cache and fresh
  loads, and Ajustes reloads branding after saving, so every screen, PDF,
  thermal receipt and CSV picks it up without threading a currency. Use
  `Money.format` / `Money.parse` / `Money.input` / `Money.major`; `CopFormatter`
  and `Formatters.money` delegate to it (legacy call sites are fine).
  Money inputs use `moneyInputFormatters()` (digits plus `.`/`,`) and validate
  with `Money.parse`. `Money.major` is what CSV exports write (`50.50`), while
  screens/receipts use the symbol (`US$50.50`). Cash denominations come from
  `Currency.denominations` (COP notes/coins vs USD 100 → 0.01).
- **Language** (`LocaleCubit`, Hive `preferences/locale`): `null` follows the
  system, otherwise `es`/`en`. It is a **device** preference, not per lot; the
  translate button in the home app bar opens system/Español/English. Tests that
  omit the cubit keep receiving `defaultLocale` (Spanish) from `ParkingApp`.
  Test bindings default to the system locale (`en`): assert Spanish strings only
  after pinning the cubit.
- Records exports: `recordsCsv` writes major units; the PDF and receipts are
  symbol-aware through `Money`.

## Operator UI + realtime (2026-10-28)

- **Capacity is the bay count** (`0060`): the editor shows `drawn / configured`
  per group, only lets you add up to the target and refuses deletions below it
  (lower the capacity in Ajustes first); the server enforces the same with
  `SpotCapacityReachedError`/`SpotCapacityRequiredError`. `capacity_snapshot`
  exposes `car_target_capacity`/`moto_target_capacity` (raw settings) next to
  the derived `car_capacity`, because once bays exist the latter reports the
  drawn count; the editor targets the former. The editor and the board share
  `SpotCellView` (72 px in the editor; the board scales 56–72 px to fit the
  card, same 6 px gap) so the dashboard mirrors the layout exactly. Empty holes
  use the same size as filled bays (no extra margins). `assign_session_spot` and check-in still use the drawn bays.
- Records (`/records`, `0062` `session_records`): the site's session log with a
  debounced server-side plate filter and paging; the header total answers "how
  many times did it enter". Rows open `/history?plate=` for the per-vehicle view
  (visits/spend). Operators can access it (`operatorRoutes` includes
  `/records`), and it sits in `primaryDestinations` (6 items on the phone bar).
  `session_records` (`0063`) also takes an inclusive business-date range
  (`p_from`/`p_to`); exports use `RecordsCubit.exportAll()` (pages server-side,
  cap 2000) with `recordsCsv` (clipboard) and `buildRecordsPdf` (share sheet).
- Legal policy (`0065`): `parking_settings.legal_policy` seeded with
  `default_legal_policy()`, editable in Ajustes (multiline + reset + preview),
  tags rendered by `renderPolicyTemplate`; `/policies?lot=..` is public and reads
  `public_lot_profile` (anon, identity/contact/policy only). The evidence page
  links to it when the function returns `lot_id`.
- Public evidence: `/evidence?session=..` is a **public route** whose gate asks
  for the plate (the link never carries it);
  (`authRedirect` allows it) backed by the `public-evidence` Edge Function
  (service role, verifies session + plate, signs Storage URLs for 1 h; uses the
  caller host so the links are reachable). Receipts print a big check-out QR
  (plate) and a smaller evidence QR; `APP_URL` (`--dart-define`) builds the
  link and the QR is omitted when unset. Deploy the public page with LAN/public
  Supabase URLs for customers. Dev sharing: build it with
  `flutter build web --release --output build/web-public
  --dart-define=SUPABASE_URL=http://<lan-ip>:8017 --dart-define=ANON...` and serve
  it from Docker (host ports are firewalled, Docker-published ones are not):
  `docker run -d --name parking-evidence-web -p 8080:80 -v $PWD/build/web-public:/usr/share/nginx/html:ro -v $PWD/tool/evidence-web.nginx.conf:/etc/nginx/conf.d/default.conf:ro nginx:alpine`.
  The nginx config falls back to index.html (path URL strategy). The app prints
  `APP_URL=http://<lan-ip>:8080`.
- Video evidence (`0064`): one optional clip per check-in (`p_videos`), same
  `evidence` bucket and `evidence_photos` rows with `kind='video'` +
  `duration_seconds`; the bucket accepts mp4/quicktime/webm up to 50 MB. The
  client records with `image_picker.pickVideo(source: camera, maxDuration: 60s)`
  (web falls back to the file picker), persists it for offline replay via the
  new `PendingPhotoStorage.persistVideo/loadVideo`, and shows the count on the
  space sheet.
- Settings hides the per-group out-of-service counters once that group has a
  map (they are a legacy count; with a map, maintenance is per bay). The form
  is sectioned and spaced; fields need `Space.md` between them, helper lines
  must reserve space (`helperMaxLines: 2`).
- **Physical map** (`0058`/`0059`): `parking_spots` (code, group, row/col,
  active) authored in `/spots` by admins (`save/delete_parking_spot`, audited).
  A group with spots derives capacity from its active bays; without spots it
  falls back to Ajustes. `check_in(p_spot_id)` validates lot/group/active/free
  or auto-assigns the first free bay (row, col); `assign_session_spot` moves a
  car. The board paints the real map and the check-in picker offers the group's
  free bays ("Automático" sends null). Delete keeps history (`spot_id` null).
  The migration runner now grants `supabase_admin` to `postgres` because a
  manual apply left `check_in` owned by the admin role, blocking a signature
  change — keep that grant in `supabase/migrate.sh`.
- **Space board** (`slot_board`, `0052`): virtual capacity cells with four
  states (free / occupied with plate + live elapsed / reserved / striped
  maintenance), icon filters, 44x48 targets, and a sheet with the exact entry
  time, a 1 s clock, the server fare and a direct exit. Admins release holds
  from the reserved cell (id resolved from `listActive` by plate + expiry).
  Component spec: [`docs/slot-board.md`](slot-board.md).
- **Money**: `fare_breakdown` (`0053`) is the only fare math; `calculate_fare`
  wraps it and `check_out_preview` returns time, day/night hours, rates, days,
  daily cap and total. Never re-implement fares in Dart; the settlement dialog
  renders those components, and a failed preview still allows charging.
- **Out-of-service** (`0054`/`0055`): `car_out_of_service` /
  `moto_out_of_service` on `parking_settings`; `usable_capacity()` gates the
  capacity trigger, `create_reservation`, `capacity_snapshot` (`*_available`)
  and the board. A group with every spot out of service is **full**, not
  unlimited; the settings form rejects a count above the capacity.
- **Touch cabins**: `PlateKeypad` (check-in field and check-out search, edits the
  shared controller) and known-plate suggestions after two characters.
- **Cash**: close/adjust dialogs show the expected cash and a live difference,
  plus a COP denomination counter (`CashCountSheet`) that fills the counted
  amount.
- **Realtime activity** (`0056`): every check-in/out notifies **all active lot
  members** with `action`, `session_id`, `plate`, `actor_name`, `actor_role`
  and (exits) `amount_charged`. The shell composes the snackbar with l10n from
  the payload; `LocalActivity` suppresses the acting device's own echo for 30 s
  (the inbox keeps the row). The arrival also **refreshes the screen**: the
  shell reloads `DashboardCubit` + `ShiftCubit`, and
  `RealtimeActivityListener` reloads the check-out list (keeping the search) and
  the check-in open sessions/holds, so data does not stay stale on the other
  device. The first version only showed the snackbar and the dashboard kept
  showing the old counters: a realtime signal that implies changed data must
  **also refetch** the cubits that own it.
- **0057 fixed the blocker**: the notifications policy used
  `current_lot_id()`, which Realtime evaluates **without** the lot header, so
  the channel died silently with `LotRequiredError`. Policies read by
  Realtime/Storage must use `can_read_lot()` / `can_read_evidence()`. Verified
  live with a `websockets` `phx_join` + `postgres_changes` probe.
- **Test flake fixed**: `rpc_test.sql` pins `timezone = 'America/Bogota'` so
  `current_date` is the business day (the suite failed between 00:00 and 05:00
  UTC, evening in Bogota).

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
`setup-local.md`, `setup-cloud.md`, `deployment-requirements.md` (hardware
minimum/recommended, evidence-based disk math, OS/network/TLS/security, cloud
sizing and go-live checklist — English), `architecture.md`,
`infrastructure.md`, `database.md`; root `QUICKSTART.md` (commands) and
`CHANGELOG.md` (changes + migration history). Diagrams are Mermaid in
Markdown; update the diagram with the code change (new table → `database.md`,
new service/port → `infrastructure.md`, new flow → `architecture.md`).

## Commands

```bash
# Flutter
flutter test
flutter analyze
flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Local stack (repo root)
docker compose up -d                 # gateway/studio on :$API_GW_HTTP_PORT (8017)
docker compose up -d supabase-migrate && docker compose logs --tail=5 supabase-migrate
docker compose restart functions     # after editing supabase/volumes/functions

# SQL suite against a scratch database
PW=$(grep -E '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
docker exec supabase-db psql -U supabase_admin -d postgres -c "drop database if exists sql_test;"
docker exec supabase-db psql -U supabase_admin -d postgres -c "create database sql_test owner supabase_admin;"
docker run --rm --network parking_management_default -v "$PWD/supabase:/work" \
  -e PGHOST=supabase-db -e PGUSER=supabase_admin -e PGPASSWORD="$PW" -e PGDATABASE=sql_test \
  postgres:17-alpine sh -c "cd /work && sh tests/run.sh"

# Realtime probe (verified 0056/0057): websockets phx_join on
# ws://localhost:8017/realtime/v1/websocket, then a check_in must produce a
# postgres_changes payload for the member (no x-lot-id header in that path).

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

## Supabase Cloud (hosted) gotcha

- A fresh Cloud project reaches Auth (`/auth/v1/health` 200) but has **no
  parking schema**: queries return `PGRST205 Could not find the table` and
  login returns `invalid_credentials` (no kiosk user). Apply
  `supabase/migrations` with `sh supabase/apply-cloud.sh <session-db-url>` and
  create the admin with `sh supabase/create-cloud-operator.sh <url>
  <secret-key> admin <pin> admin`.
- The publishable key (`sb_publishable_...`) works as `apikey`; `/rest/v1/`
  answering "Secret API key required" with it is normal (admin-only root).
- Never put `sb_secret_...`/service_role or third-party keys (Groq, etc.) in
  the client or in `--dart-define`; only the publishable key ships.

## Local gateway port

- The local gateway port is `.env` `API_GW_HTTP_PORT` (currently **8017**),
  mirrored in `SUPABASE_PUBLIC_URL`, `API_EXTERNAL_URL` and `SITE_URL`. After
  changing it: `docker compose up -d --force-recreate api-gw auth`.
- `tool/run-android.sh` reads that port (or `SUPABASE_PORT`) and reverses it;
  Flutter gets `SUPABASE_URL=http://localhost:<port>`. e2e/healthcheck read
  `SUPABASE_PUBLIC_URL` from `.env`.
- Port 8000 is no longer bound in this environment.

## Dev environment running (2026-10-28)

- Backend: `docker compose up -d` from the repo root; all services healthy,
  gateway/Studio on <http://localhost:8017> (`API_GW_HTTP_PORT` in `.env`);
  migrations `0001`-`0059` applied.
- Flutter web: `flutter run -d chrome --dart-define=SUPABASE_URL=http://localhost:8017
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>` (log: `/tmp/opencode/flutter-web.log`).
- Android (Samsung S901E over wireless adb): `sh tool/run-android.sh` — it
  re-applies `adb reverse` and runs with `SUPABASE_URL=http://localhost:8017`.
  Install-only alternative: `flutter build apk --debug --dart-define=...` then
  `adb install -r ... && adb shell am start -n
  pro.devpaul.parking_management/.MainActivity`.
- Login: `admin` / `123456`. Dev data: lot 1 "Parqueadero" (categories + data)
  and lot 2 "Sede Norte" (member `norte2`, **no categories**: a new vehicle
  cannot be registered there until categories/tariffs are created).
- The apps use `localhost:8017`; if the phone shows "cannot reach the server",
  check `adb reverse --list` first (see below), not `ufw`.

## Android over adb

- `tool/run-android.sh [serial]` re-applies `adb reverse tcp:8017 tcp:8017` and
  runs Flutter with `SUPABASE_URL=http://localhost:8017`. **Wireless adb
  reconnects on a new port and drops every reverse mapping** — the app then
  cannot reach the backend until the reverse is re-applied. No `ufw` rule is
  involved on that path; only a LAN URL needs `ufw allow 8017/tcp`.
- `adb shell curl -s -o /dev/null -w '%{http_code}' http://localhost:8017/rest/v1/`
  must answer `401` (reachable); `000` means the tunnel is missing.
- The wireless serial changes on every reconnect (`192.168.0.2:<port>`): read it
  from `adb devices` instead of hardcoding it. `adb exec-out screencap` returns
  a black PNG on this device (locked screen), so verify the app with
  `dumpsys window | grep mCurrentFocus` + the REST probe, not screenshots.

## Boot order (fresh installs)

- `configureDependencies()` initializes `KeyValueStore` (Hive) **before**
  `_initSupabase`: the boot clears a stale cached session through Hive, which
  needs `Hive.init(path)` on mobile (web needs no path, so the bug only showed
  on a fresh Android install).
- Android over adb: `adb reverse tcp:8017 tcp:8017` + `SUPABASE_URL=
  http://localhost:8017`; no firewall/Wi-Fi involved. Both are documented in
  QUICKSTART and the environment guides.

## Space capacities and keys (0047)

- `parking_settings`: `car_capacity` (cars + pickups share the pool),
  `moto_capacity`, `key_capacity`; `0` = no limit. Trucks/buses are excluded by
  design. Editable in Ajustes.
- `parking_sessions.left_keys` (default false) travels through the check-in
  form, `check_in(p_left_keys)`, the queued payload (`left_keys`) and the
  replayer; `open_sessions_view` exposes it.
- `enforce_category_capacity()` keeps the per-category cap and adds group caps
  (category name sets are the contract for groups) and the keys cap, all under
  advisory locks per lot/group. Errors: `ParkingFullError`, `KeysFullError`.
- The check-in RPC signature gained a trailing `p_left_keys` default; the old
  8-argument overload must stay dropped (two overloads make calls ambiguous).
- `0049` makes active reservations count against the category and group
  capacities (walk-ins cannot take a held spot); the capacity trigger and
  `create_reservation` share the advisory locks and the same group name sets.
- `0054`/`0055` add out-of-service spaces: `parking_settings.car_out_of_service`
  / `moto_out_of_service` stay inside the configured capacity but are removed
  from the usable pool by `usable_capacity()` (`0` capacity = no limit, and it
  ignores the counter). The trigger, `create_reservation`, `capacity_snapshot`
  (`*_available`) and `slot_board` all use it; the board paints striped
  "Mantenimiento" cells that are not interactive.
- SQL test timezone gotcha: `supabase/tests/rpc_test.sql` sets
  `timezone = 'America/Bogota'` so `current_date` matches the business day.
  Without it the suite fails between 00:00 and 05:00 UTC (evening in Bogota).
- `0053` makes `fare_breakdown` the only money math (`calculate_fare` wraps it,
  `check_out_preview` returns its components). Never re-implement the fare in
  Dart: the settlement dialog and the board sheet render the server breakdown.
- `0052` adds `slot_board()` (capacities + sessions + holds, lot-scoped) and the
  home `SlotBoardCard`. Cells are **virtual capacity** cells, not bay numbers:
  sessions first, then holds, then free. Occupied cells carry plate + elapsed;
  reserved cells carry the hold expiry. A board failure falls back to an empty
  board so the dashboard keeps working. The detail sheet refreshes the clock
  every second and the preview every 60 s.
- `0057` fixes the notifications RLS policy: Realtime has no `x-lot-id`, so the
  old `current_lot_id()` raised `LotRequiredError` and the channel silently
  dropped events. Policies evaluated by Realtime/Storage must use membership
  helpers (`can_read_lot`, `can_read_evidence`), never the active-lot helper.
  Verified with `websockets` against `/realtime/v1/websocket`
  (`phx_join` → `postgres_changes` after a check-in).
- `0056` notifies **every active lot member** (including the actor) on
  check-in/check-out with `data.action`, `session_id`, `plate`, `actor_name`,
  `actor_role` and (exits) `amount_charged`; Realtime delivers it to each
  member. The shell composes the snackbar with l10n from the payload (not the
  Spanish server body) and skips it when `LocalActivity.owns(action, sessionId)`
  (the acting device remembers its write for 30 s). Operators now receive their
  own rows; the RLS test asserts they never read another user's.
- Cash closing shows the expected cash and a live difference, and a
  denomination counter (`CashCountSheet`, COP notes/coins) fills the counted
  amount; both the close and the admin adjust dialogs use it.
- Touch cabins get an on-screen alphanumeric keypad (`PlateKeypad`, opened
  from the plate field and the check-out search); it edits the shared
  controller, so validation/lookup/debounce run as if typed.
- Check-in loads one page of known vehicles (`listPage(limit: 200)`) and shows
  up to four prefix matches as `ActionChip`s once two characters are typed;
  the repository is injectable, and a failure just hides the suggestions.
- Hold release on the board: `SlotHold` has no id (the payload stays lean), so
  the admin action resolves the reservation through
  `ReservationRepository.listActive()` by plate and expiry (±60 s), then
  cancels it and reloads the dashboard. The repository is injected through
  `HomePage.reservations` (router uses `isRegistered` so router tests still
  work).
- Out-of-service invariants: never offer a spot that is out of service, and
  never treat "all spots out of service" as unlimited. The settings form
  rejects an out-of-service count above the configured capacity.
- UI/UX invariants: state is never colour-only (each cell has a label and a
  group icon), cells stay ≥ 44×48 dp, and the occupancy KPI paints its
  percentage as text next to the radial gauge.
- `0051` adds `reservations_active`/`reservations_expiring` (2 h) to
  `capacity_snapshot`; the capacity card shows "N reservas activas"/"N por
  vencer" and admins get a shortcut to `/reservations`.
- Check-in loads the active holds (injected `ReservationRepository`) and shows
  a banner for the typed plate with a cancellable hold; holds reload after a
  check-in or cancellation.
- `0050` adds `car_reserved`/`moto_reserved` to `capacity_snapshot()`; the
  capacity card renders them under the bar ("N reservados").
- `0048 capacity_snapshot()` returns `car_open/car_capacity`,
  `moto_open/moto_capacity`, `keys_open/key_capacity` for the home. The
  `CapacitySnapshot` entity + `CheckOutRepository.capacitySnapshot()` feed
  `DashboardLoaded.capacity`; `DashboardCubit` also loads the first 5 open
  sessions and resolves their plates through an optional `VehicleRepository`.
- Home layout: actions first; `_SummaryGrid` puts occupancy/capacity and
  today/shift in two equal-height columns from 720 px (one column on phones);
  management shortcuts are a two-column tile grid; cards share `_KpiIcon`.
- Home widgets: `CapacityCard` (bars, `0` = "no limit") and `InsideCard`
  (plates + elapsed + pass/photo hints; "See all" → `/check-out`, row tap →
  `/check-out?plate=`). `OccupancyCard` now counts only configured group
  spaces; from `Layout.homeSplit` (1000) the inside list moves to a 340 px
  side panel. Check-in disables a category when its whole group is full
  (`core/utils/vehicle_groups.dart`, same names as the SQL trigger).

## Receipt QR / check-out scanning

- `QrCode` generates the matrix for the *inner* square (size − 2×12) and paints
  it unscaled inside that padding; sizing it outside the padded canvas clipped
  the last modules. `test/core/widgets/qr_code_test.dart` renders the widget to
  a PNG and decodes it with the camera decoder, so a clipped QR fails CI.
- The QR payload is the **plate** (`Barcode.qrCode()` in `core/widgets/qr_code.dart`),
  printed on the **entry** receipt (screen, PDF via `pw.BarcodeWidget`, thermal
  via `GS ( k`) and captioned with `ReceiptLabels.scanHint`. Check-out receipts
  carry no QR: the car is already gone.
- `scanQrWithCamera` (`core/qr/qr_scan_page.dart`, `mobile_scanner`) is the
  phone path: a live preview with torch, one result pops the page (haptic).
  Web has no live scanner; the check-out page and the shell FAB fall back to
  `PlateImageCapture` + `QrDecoder` (file/photo).
- `QrDecoder` (`core/qr/qr_decoder.dart`, zxing2 + image, pure Dart) decodes the
  web capture; `plateFromQrPayload` accepts a bare plate or `?plate=`/`?p=` and
  rejects anything else (a random QR cannot start a check-out).
- Check-out: `resolvePlate` asks the server for the exact plate (limit 2, only a
  single match opens); `_startCheckout` moved from the tile to the page so the
  scan and a USB reader's `Enter` (`SearchField.onSubmitted`) reuse it.
- Check-in success opens `showReceipt` with the QR + Imprimir (no summary step)
  and restores plate focus when the dialog closes.
- Check-in category options append the group's remaining spaces
  (`categorySpotsLeft`, held spots subtracted, `categoryNoSpots` when zero);
  groups without a configured capacity stay plain.
- Check-in's "vehicles inside" is a local accordion (`_sessionsOpen`) with a
  count badge; rows expose the ticket (receipt + print) and "Mark exit"
  (`/check-out?scan=<plate>`; `onMarkExit` is injectable for tests).
- Open sessions now carry `photo_count` (the view already exposed it) so the
  check-out list can reprint an entry ticket: admins get a receipt icon per row
  that opens the QR ticket with Imprimir. Operators do not (security test).
  The row subtitle is a `Wrap` with the elapsed label ellipsized: the extra
  action narrowed the row enough to overflow at 400 px (regression test at that
  width).
- The shell FAB is the QR scanner (`_ScanQrFab`, hidden without capture/decoder):
  it navigates to `/check-out?scan=<plate>`, which resolves and opens the
  payment dialog. The old WhatsApp FAB (and its test) is gone; WhatsApp lives in
  `/contact`.
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

## Latest verification (2026-10-28)

- `flutter test`: 815 passed (+1 live-stack integration skipped); `flutter
  analyze` 152 infos, all SDK `deprecated_member_use` (zero warnings/errors);
  `flutter build web --release` OK.
- `supabase/tests/run.sh` passed (migrations `0001`–`0067`); `e2e.sh` passed
  (login → check-in → check-out → report → history).
- `healthcheck.sh`: 0 failures (one warning for a dev shift left open >12 h).
- Batches this session: space board + settlement breakdown (0052/0053),
  out-of-service (0054/0055), plate keypad, hold release, cash counter, realtime
  notifications (0056/0057), physical map + editor (0058/0059), capacity=bays
  (0060/0061), records + exports (0062/0063), evidence video (0064), shareable
  evidence + plate-keyed public page + legal policy (0065), card debit/credit
  (0066), cash received/change (0067), 5-tab phone nav + drawer and the
  receipt print-sheet fix. Full list in `CHANGELOG.md`; specs in
  `docs/slot-board.md`.
- Hardware run found and fixed two boot bugs: Hive now initializes before the
  Supabase session cleanup, and evidence uploads are insert-only (see above).

## Deployment requirements (2026-10-28)

- `docs/deployment-requirements.md` is the canonical English list: shapes (edge
  VM / cloud VM / managed Supabase), 2 vCPU/4 GB/40 GB minimum and
  4/8/80–160 recommended (8/16/320+ multi-site), disk formula
  `vehicles/day × (photos + video% × video MB) × retention ÷ 1024`, Ubuntu
  24.04 + Docker 24/Compose v2, only 443 public (8000/5432/6543 loopback),
  WebSocket + ≥60 MB body limit, bandwidth ≥5 Mbps upload for video, offsite
  encrypted backups + restore drill, and the go-live checklist.
- Idle full stack ≈1.2 GB RAM (docker stats); plan 2–3× headroom. Studio/meta
  can be disabled in production; amd64 images only.

## Backlog / next moves

- `5.4` contract migration: drop the missing-header fallback once every client
  sends `x-lot-id`.
- Optional polish: per-lot receipt footer beyond settings, audit free-text
  search, configurable shifts; the lot switcher could later live in an app-bar
  menu instead of the home chip.
- Dev DB is intentionally minimal (see "Dev DB cleaned"): do not recreate the
  `NORTH` lot, `norte2`/audit users or test vehicles; clean `E2E*` rows after
  running the e2e suite. The public evidence container
  (`parking-evidence-web`, port 8080) must stay up for shared links in dev.
