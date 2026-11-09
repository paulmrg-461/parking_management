# Agent memory

Durable context for any agent working on this repo. Read this first, then
`AGENTS.md` (rules) and `PROGRESS.md` (product history). Keep it short and
current: append decisions and gotchas, delete what the code now explains.

Last updated: 2026-11-09 (startup splash, PDF hourly chart, parallel loads).

## Where we are

- Stack: Flutter (android + web) + self-hosted Supabase only. No FastAPI,
  Alembic, Dio, Redis or `backend/` — never reintroduce them.
- `supabase/migrations/0001..0086` are the schema owner (applied by
  `supabase-migrate`); SQL RPCs own business logic; RLS everywhere.
- Flutter: 1067 tests green, `flutter analyze` reports only SDK deprecation
  infos from the pinned beta channel (0 errors/warnings). Web build green.
  `supabase/tests/run.sh` and `supabase/tests/e2e.sh` green.
- OpenSpec: multi-lot archived (`openspec/specs/parking-lots`); the only open
  item is the manual smoke for `add-parking-settings` (task 10.4).

## Live deployment (2026-11-05)

- Web dev + public host `http://192.168.0.17:8080`, API `:8017`, APK installed
  and open on `192.168.0.2:34591` (the wireless serial changes on reconnect;
  read it from `adb devices`). Login `admin` / `123456`.
- Lot 1 has `police_phone` empty on purpose: the emergency panel falls back to
  **123** until the quadrant is configured in Ajustes → Emergencias.
- Live smoke against PostgREST passed: `vehicles.owner_name` is selectable,
  `update_vehicle_flags`/`vehicle_history` return `owner_name`, and
  `parking_settings.police_phone` can be PATCHed and cleared. The smoke left
  the column empty.
- Screenshots work with `adb exec-out screencap -p` while the phone is
  unlocked; a black PNG means the screen was locked. Verified the red
  emergency appbar button and the emergency panel this way.

## Owner preferences (durable)

- The owner writes in **Spanish** and expects Spanish replies; code, comments,
  tests, docs and OpenSpec artifacts stay **English** (see `AGENTS.md`).
- Visual work is iterative: they ask for "más bonito" and expect the shared
  design system (tokens, `MetricCard`, `SectionHeader`, `FilterBar`, empty/error
  states) to be used, never one-off styling. Keep `docs/ui-kit.md` truthful.
- Every batch: `flutter test` + `flutter analyze` + SQL suite, rebuild web and
  APK, restart the Chrome dev app, commit and push (never leave it unpushed).
  Report the phone/adb state honestly when the device is offline.

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

## Emergency action (2026-11-05)

- `parking_settings.police_phone` (`0079`, 3..15 digits or empty) is edited in
  **Ajustes → Emergencias**. `EmergencyAction` sits in every app bar
  (`ListPageScaffold` covers the admin lists) and in the sidebar footer; the
  phone drawer has a highlighted `EmergencyDrawerTile`.
- The panel shows the site name/address (to report), the quadrant number and a
  56 dp call button. Empty setting falls back to **123**; admins see
  "Configurar en Ajustes", operators a note to ask the admin.
- `test/features/emergency/presentation/emergency_dialog_test.dart` covers the
  configured number, the 123 fallback and the settings shortcut; the settings,
  shell, SQL and repository tests cover the rest. Test count: 993, schema
  `0001..0079`.

## Home weekly trend (2026-11-06)

- `0080_dashboard_trend` adds `dashboard_trend(p_days default 7, allowed
  1..31)`: `security definer`, `require_app_user()`, lot-scoped through
  `current_lot_id()`, business timezone. It returns
  `{lot_id, start_date, end_date, days:[{date, revenue, entries, exits}]}` and
  uses `generate_series`, so quiet days are zero rows (the client never fills
  gaps). Operators may call it (unlike `report_revenue`); an out-of-range
  `p_days` raises `InvalidTrendRangeError`.
- `CheckOutRepository.dashboardTrend()` feeds `DashboardLoaded.trend`; a failed
  trend degrades to `DashboardTrend.empty` without hiding the rest of the home
  (same rule as `todaySummary`). `TrendCard` in
  `home/presentation/widgets/dashboard_widgets.dart` paints the bars scaled to
  the peak day (today in `tertiary`), the weekly revenue/entries/exits totals,
  a skeleton while loading and a quiet-week message; admins get a reports
  shortcut, operators do not.
- Tests: entity parsing, cubit degradation, card totals/quiet/failure and the
  admin-only shortcut; SQL covers the contiguous 7-day series, today's revenue,
  invalid ranges and lot isolation. Test count: 1013; schema `0001..0080`.
- The new 400 px + 1.6 text-scale test exposed a pre-existing overflow in
  `_CapacityRow` (home capacity card): its label is now clamped to two lines
  and the counter is a flexible, ellipsized `Text`. Keep the test; it guards
  both cards.

### Home trend comparison + parallel load (2026-11-09)

- The dashboard asks for `dashboard_trend(days: 14)`. `TrendCard` paints the
  last 7 (`window(7)`) and compares them with `window(7, skip: 7)`: success
  chip when revenue grows, warning when it drops, neutral "same as last week"
  when flat, and no chip when the previous window is incomplete or earned
  nothing (a zero base would divide by zero).
- `DashboardCubit._fetch` awaits occupancy first, then runs today / trend /
  capacity / board / inside with the record `.wait` (concurrent, each with its
  own `catchError`). `FakeCheckOutRepository.todayGate` + `pumpEventQueue`
  prove the extras start before the gated one finishes.
- The KPI grid shows `SkeletonPulse` + four `SkeletonCard`s while the first
  load is in flight. `SkeletonPulse`/`SkeletonCard` are public in
  `core/widgets/skeleton.dart` (`SkeletonCardList` reuses them).
- Gotcha: never `pumpAndSettle` while the dashboard is still loading — the
  skeleton pulse repeats forever. Use `pump()` and complete the gate first.

### Bay maintenance history (2026-11-09)

- `0081` adds `parking_spot_events` (lot, spot, spot_code, status, reason,
  actor, created_at; RLS `lot_id = current_lot_id()`, select grant only). The
  RPC `save_parking_spot` gained a trailing `p_reason text default null` and
  logs a row on real status transitions (a bay created already out of service,
  or an update that changes the status). A no-op save does not pollute it.
- The 6-argument `save_parking_spot` overload is **dropped on purpose**: with
  the trailing default, keeping both makes 6-argument calls ambiguous (same
  trap as `check_in`). Positional test calls still work.
- `list_spot_events(p_spot_id, p_limit default 20)` returns newest first and
  must order by `created_at desc, id desc`: `now()` is constant inside a
  transaction, so the id is the tiebreaker between two transitions made in the
  same RPC/test.
- UI: turning a bay off reveals an optional reason (3..200 characters or
  empty; shorter values are blocked client-side), "Ver historial" opens a
  dialog with skeleton/empty/error+retry, and the editor refreshes
  `DashboardCubit` whenever the map changes so the home board is not stale.
  Operators can read the history; only admins can change a bay.
- Live smoke (PostgREST): took bay S1 out with "prueba de humo", the event came
  back with actor Admin and the reason, then restored it and deleted the two
  smoke rows. Test count: 1022; schema `0001..0081`.

### Offline dashboard cache (2026-11-09)

- `DashboardSnapshot` (`home/domain/entities`) serializes occupancy, today,
  trend and capacity + `cachedAt` as versioned JSON. `DashboardCache` is the
  port; `HiveDashboardCache` stores it in the `cache` box under
  `dashboard_<lot>` so switching sites never shows another site's numbers.
  `HiveKeyValueStore.init()` opens `cache` for the same cold-start reason as
  `preferences` (`get` is synchronous and only sees open boxes).
- `DashboardCubit` writes the cache only after a **complete** load (occupancy
  plus today/trend/capacity all succeeded); a degraded load never overwrites a
  good snapshot. On a failed initial/lot-switch load it reads the cache and
  emits `DashboardLoaded(cachedAt: ...)` (`isStale`); without a cache it still
  emits `DashboardFailure`. Cache read/write errors are ignored.
- The stale state carries only the KPIs: the space board and inside list stay
  empty and `HomePage` hides them (including the wide side panel), showing
  `_StaleDashboardNotice` above the summary with the capture time and a retry.
  The shell `OfflineBanner` still reports connectivity separately.
- Coverage floors raised with the new domain tests: global 79 (79.2 measured),
  application 90 (90.7), domain 52 (53.3), infrastructure 40 (40.3).
  Test count: 1030; schema `0001..0081`.

### Hourly traffic reports (2026-11-09)

- `0082_report_hourly_traffic.sql`: `report_hourly_traffic(date, date)` is
  admin-only (`require_admin()`), lot-scoped, and returns
  `{start_date, end_date, timezone, hours:[{hour, entries, exits}]}` for all
  24 business-day hours (quiet hours included). Entries count `entry_time`;
  exits count closed `exit_time`; the 0069 lot/entry and lot/exit indexes cover
  both.
- `HourlyTraffic`/`HourlyTrafficPoint` sort the buckets; `ReportsCubit` loads
  it in the same `Future.wait` as the other reports and **degrades to empty**
  when the RPC fails, so the page never fails because of the chart.
  `HourlyTrafficChart` is a 4/6/8-column grid scaled to the peak entry hour,
  with a peak-hour summary, per-cell tooltip/semantics (entries + exits), an
  empty state and a legend.
- The new 400 px test exposed a pre-existing overflow in `_DeltaRow` ("vs
  previous period"): it now uses a `Wrap`, so it flows to a second line instead
  of overflowing the summary card.
- Coverage: global 79 (79.3), application 90 (90.7), domain 53 (54.2),
  infrastructure 40 (40.2). Test count: 1036; schema `0001..0082`.
- Live smoke: `report_hourly_traffic(2026-11-03, 2026-11-09)` returned 24
  buckets with the expected entries/exits and `America/Bogota`.
- Follow-up: the report presets added **Este mes / Mes anterior** (calendar
  boundaries) and moved from a `SegmentedButton` to `ChoiceChip`s inside the
  `FilterBar`, so they wrap on phones. `reportCsv` gains
  `hourly_entries`/`hourly_exits` raw rows and `buildRevenueReportPdf` a
  "Tráfico por hora" table via `reportHourlyRows`; both include only hours
  with movement. Test count: 1039.

### Audit search (2026-11-09)

- `0083_audit_search.sql` drops/recreates `list_audit_log` with a trailing
  `p_search text default null` (the 5-arg overload must stay dropped: with the
  default, leaving both makes 5-arg calls ambiguous). It also fixes a real bug:
  the old version limited the newest N rows **before** filtering by actor, so
  selecting an actor only searched that page. Filters now run in the scan and
  the limit applies last.
- Search is case-insensitive over `entity_id`, `table_name`, actor
  username/display name, and `after`/`before` `plate`/`name`; an empty term
  means no filter and it composes with table/actor/date. JSONB text is not
  searched wholesale (avoids matching timestamps/keys by accident).
- Flutter: `AuditLoaded.search` + `AuditCubit.load(search:)`; the page adds a
  300 ms debounced `SearchField`, clears it with "Limpiar filtros", and the PDF
  subtitle includes the term. Tests cover search persistence, clearing and the
  debounced reload. Test count: 1041; schema `0001..0083`.
- Live smoke: `list_audit_log` with `p_search=LCR481` returned the vehicle row
  (`entity_id 34`).

### In-app evidence viewer (2026-11-09)

- `0084_vehicle_history_evidence.sql` redefines `vehicle_history` with a
  per-session `photo_count`, scoped to `current_lot_id()`: the history lists
  sessions from every site, but evidence viewing (and its count) follows the
  active lot, matching the evidence RLS policy.
- `SessionEvidenceRepository` lists `evidence_photos` and signs each object for
  one hour. A refused signature keeps the row with `url = null` (the tile shows
  a cloud-off placeholder instead of hiding that evidence exists); list errors
  map to a `Failure` and the sheet offers retry.
- The history tile shows "Ver evidencias (N)" when `photo_count > 0`, below the
  amount so the action row never overflows a 360 dp phone. The bottom sheet has
  a photo grid (tap → black `InteractiveViewer` dialog) and video tiles (tap →
  external player), with skeleton/empty/error states.
- Tests: SQL photo_count, entity parsing, remote signing/denied/list-failure
  with a MockClient, repository delegation, sheet states and the history
  action. Test count: 1051; schema `0001..0084`.
- Follow-up: the check-out row also shows an "Evidencias (N)" `ActionChip`
  when the session has photos, using the same sheet (`CheckOutPage`'s
  `evidenceRepository` is the test seam). It wraps with the status chips, so
  the 400 px row stays overflow-free. Test count: 1052.
- Live smoke: `vehicle_history('LCR481')` returned session 48 with
  `photo_count: 2` (session 43 has 0).

### Site setup checklist (2026-11-09)

- `0085_lot_setup_status.sql` adds `lot_setup_status()` (any lot member):
  category count, active tariffs, car/moto capacity, active bays and
  address/phone flags. `complete` requires categories, tariffs and
  capacity-or-bays plus address and phone. It is `security definer` and reads
  `current_lot_id()`.
- `CheckOutRepository.lotSetup()` feeds `DashboardLoaded.setup` (unknown on
  failure, never a false "unconfigured"). `SetupChecklistCard` on the home is
  admin-only, hidden when complete/unknown, and shows 4 steps with a progress
  bar and links (`/categories`, `/tariffs`, `/settings`). Operators never see
  it; the card is the onboarding fix for the "new lot without categories"
  gotcha.
- Tests: SQL flags against `parking_settings` and an incomplete lot, entity
  step math, cubit fallback to unknown, and home visibility for admin/
  operator/complete. Coverage floor: domain 54 (55.0 measured). Test count:
  1058; schema `0001..0085`.
- Live smoke: `lot_setup_status()` for lot 1 returned
  `complete: true` (5 categories, 7 active tariffs, capacity 20/10,
  address/phone set).

### Evidence from records (2026-11-09)

- `0086_session_records_evidence.sql` recreates `session_records` with a
  `photo_count` per row (the query is already lot-scoped, so no extra filter is
  needed). The activity log shows "Evidencias (N)" under the times when the
  count is positive and opens the shared evidence sheet; the log row still
  opens the vehicle history when tapped elsewhere.
- `SessionRecord.photoCount` + `RecordsPage(evidenceRepository:)` (test seam).
  Tests cover the SQL count, the parser and the log action; no evidence is
  queried until the operator taps the action. Test count: 1059; schema
  `0001..0086`.
- Live smoke: `session_records` for `LCR481` returned session 48 with
  `photo_count: 2` (session 43 with 0), matching `vehicle_history`.

### Revenue chart in the PDF (2026-11-09)

- `buildRevenueReportPdf` now draws a compact bar chart above the by-day table:
  `revenueBarHeights` (pure, tested) scales the best day to 68 pt and zero days
  to 0; `buildRevenueBarChart` renders it with the first/last dates underneath
  and no per-bar labels (the table below keeps the exact numbers). An empty
  range skips the chart, and quiet periods keep flat bars.
- No new SQL. Test count: 1061; schema `0001..0086`.

### Parallel page loads (2026-11-09)

- `ShiftCubit.load` runs `current()` and the admin `history()` in one
  `Future.wait`; `ReservationsCubit.load` runs active reservations and
  categories together; `MonthlyPassesCubit.load` starts passes, pending
  payments, vehicles and tariffs together (`Future.wait<Object>` + casts,
  still wrapped in the `on Failure` handler so list failures keep their
  screen-level state). Each page saves one or more sequential round trips.
- Tests use gates on the first fake call (`currentGate`, `activeGate`,
  `listGate`) and `pumpEventQueue` to assert the second call already started.
  Test count: 1064; schema `0001..0086`.

### Hourly chart in the PDF (2026-11-09)

- The hourly section of the revenue PDF now draws 24 bars (`buildHourlyBarChart`)
  scaled to the busiest entry hour, with 00/06/12/18/23 labels; the table below
  keeps exact entries/exits. `hourlyBarHeights` is pure and tested (busiest =
  68 pt, zero hours = 0). No new SQL. Test count: 1066.

### Startup splash (2026-11-09)

- `main()` now `runApp`s a minimal `_BootstrapSplash` (logo + loading, theme
  and locale from the cubits) **before** `await authCubit.restore()`. The real
  `ParkingApp` replaces it once the restore (Hive session + lot memberships +
  `x-lot-id`) resolves, so a slow network no longer leaves a blank screen.
  `initialLocation` stays `homePath`, so deep links/bookmarks are unaffected.
- `AuthCubit.restore` catches local-storage errors and emits
  `AuthUnauthenticated` (a corrupt cache lands on login, never a stuck splash).
  `SyncService.start()` still runs after the restore so queued writes never
  fire token-less.
- `SplashPage` test covers the brand + progress; test count: 1067.

## Owner contact data (2026-11-05)

- `vehicles.owner_name` (`varchar(120)`, trimmed 2..120) joins the existing
  `owner_phone`. Both are optional and admin-editable from the vehicle list
  (edit dialog) and the vehicle history ("Datos del propietario" dialog).
- `update_vehicle_flags` gained `p_owner_name default null` (new 5-arg
  signature; old callers still work) and returns `owner_name`; the
  `vehicle_history` JSON exposes it too. `null` keeps the value and an empty
  string clears it, same as notes/phone.
- App write path: `UpdateVehicleCommand.ownerName/ownerPhone`; `null` keeps the
  stored value and an empty string clears it. Direct PATCH (0075 grant) sends
  JSON `null` to clear. Covered by repository, DTO, dialog, history and SQL
  tests. Test count: 993, schema `0001..0079`.

## Monthly pass tariff (2026-11-05)

- `MonthlyPassesCubit` now takes an optional `TariffRepository` (DI passes the
  real one), loads tariffs with the vehicles and exposes
  `monthlyTariffByCategory`/`monthlyTariffFor`. The pass dialog prefills the
  amount from the active `monthly` tariff of the selected vehicle's category,
  re-prefills when the vehicle changes and offers "Usar tarifa mensual (…)"
  (editing keeps the saved amount until the button is used).
- No schema change: the pass still stores its own amount; the tariff is the
  source for the form, not a live dependency.
- Test count: 975.

## Preference persistence (2026-11-05)

- Auto-lock/language/theme/sidebar are **device-local** in Hive
  (`preferences/*`), not in Postgres. `KeyValueStore.get` is synchronous and
  only reads **already-open** boxes; the store opened `preferences` lazily on
  the first `put`, so a cold start silently reset everything to defaults
  (auto-lock back to 5). `HiveKeyValueStore.init()` now opens the box before
  any cubit restores. Covered by a real-Hive restart test.
- Reinstalling the app or clearing data still resets these preferences (they
  are not synced across devices; that is intentional).
- Test count: 972.

## Settings/about navigation (2026-11-05)

- Replaced the sidebar's five preference icons with two footer links:
  **Ajustes** (`/preferences`, operator route) and **Acerca de** (`/about`).
  The drawer mirrors them plus Ayuda (also reachable from Ajustes) and logout.
- `PreferencesPage` holds language, appearance and auto-lock with their pickers;
  it uses `context.push` for Help/About. Tests pin `testApp` to Spanish, so
  changing the language cubit there does not relabel the page.
- About copy: Paul is a **Systems Engineer** with 7+ years in web/mobile plus
  backend/database/infrastructure (not "Flutter only"); the developers card
  lists Paul and Jimmy.
- About shows a **Desarrolladores** card with Paul Realpe (DevPaul) and
  **Jimmy Realpe** (`jimmy-realpe.web.app`), both using the injectable launcher.
- Test count: 971.

## Public QR contact (2026-11-05)

- `public-evidence` now returns `lot` (id, name, phone, whatsapp, address,
  schedule, `logo_url`). The logo is a **public** branding bucket URL built from
  the request host (`/storage/v1/object/public/branding/<logo_path>`), so the
  customer can load it without auth. Missing logo falls back to the parking icon.
- The public page header shows logo + name + address/schedule, plus Call
  (`tel:`) and WhatsApp (`wa.me` with the plate prefilled) buttons. The plate is
  still the access key; contact data only appears after unlocking.
- Live check: session 55/MJS368 returned the lot and a 200 logo URL.
- Test count: 968.

## Public QR summary (2026-11-05)

- `0077_public_session_summary.sql` adds
  `public_session_summary(p_session_id, p_plate)`: plate-keyed, `security
  definer`, granted to **anon**; returns duration, currency, current fare (or
  `amount_charged` when closed), `has_pass` and the fare breakdown. Wrong plate
  or unknown session returns null.
- `public-evidence` calls the RPC with the service key and includes `summary`
  (failure never hides evidence). The public page shows two `MetricCard`s with
  `Formatters.duration` and `Money.formatAs(currency, amount)`; open sessions
  add "Puede cambiar hasta la salida".
- SQL tests cover authenticated and anon execution plus the wrong-plate case.
  A live call on session 55 (MJS368) returned duration 2349 s, COP 5000.
- Test count: 967.

## Quality ratchet (2026-11-05)

- Contract tests for DTOs/domain parsers (`test/core/contracts`) plus the
  coverage floors in `tool/check_coverage.dart`: global 78 %, application 90 %,
  domain 47 %, infrastructure 38 % (measured 78.5 / 90.7 / 49.0 / 40.0). Raise
  them when a layer improves; generated `.g.dart` and `l10n` stay ignored.
- Test count: 966.

## Network resilience (2026-11-05)

- `ResilientHttpClient` wraps Supabase's `httpClient`: 20 s per-request timeout
  (storage uploads exempt), GET/HEAD retries on timeouts, `ClientException` and
  502/503/504 with linear backoff (2 retries). Writes are **never** retried in
  the transport; idempotency belongs to RPCs/outbox.
- Counters (`NetworkMetrics`: timeouts/retries/failed, process-local) appear in
  `/diagnostics` → "Client network". `setUp(NetworkMetrics.reset)` in tests.
- Sentry is **not** wired yet: it needs a DSN/hosting decision; the existing
  `ErrorReporter` + diagnostics counters are the current observability path.
- Test count: 954.

## Help and version guard (2026-11-05)

- `/help` (operator route) is a searchable help center built from localized
  entries; search matches title **or body** (so short words like "arqueo" match
  several articles), and a non-empty query auto-expands the matching tiles.
  Entry points: drawer and sidebar.
- `0076_min_app_version.sql` adds `parking_settings.min_app_version`
  (`''` or `major.minor[.patch]`, check constraint) and exposes it from
  `public_lot_profile`. `core/version/app_version.dart` compares numerically;
  an empty/invalid minimum never blocks. `VersionBanner` in the shell shows the
  localized warning when the build is older. Settings has the admin field.
- Test count: 950.

## Idle lock (2026-11-05)

- `AutoLockCubit` (device preference `preferences/auto_lock_minutes`, default 5,
  options 0/1/5/15/30) + `AppLockGate` wired through `MaterialApp.builder`.
  Pointer and hardware-key activity reset the clock; a 15 s timer and app
  resume call `check()`. The overlay only shows while signed in, and stays up
  through `AuthLoading`/`AuthFailure` during a PIN attempt.
- `LockScreen` re-authenticates with `AuthCubit.login(username, pin)` (no PIN
  stored locally); 5 wrong attempts sign out. Sign-out from the overlay
  releases it via the gate's auth listener.
- Timeout is chosen from the drawer (`Auto-lock` row) or the desktop sidebar
  (lock icon, bottom sheet); `AutoLockCubit.restore()` runs in the gate.
- Tests: cubit clock/activity/disabled/persistence and gate unlock/wrong-PIN/
  sign-out. Test count 939.

## Vehicle editor (2026-11-03)

- The vehicles list now exposes `EditVehicleDialog` (category/brand/color; plate
  read-only) for admins. `VehiclesCubit` reports `lastAction` (created/updated)
  so the page shows "actualizado" instead of the create/check-in prompt.
- `0075_vehicle_update_grant.sql` adds the missing `UPDATE` grant on
  `public.vehicles`; the `vehicles_admin_write` policy already limited writes to
  admins (SQL test proves admins update 1 row, operators 0).
- Test count: 931.

## Production guards (2026-11-03)

- `0074_statement_timeouts.sql` bounds PostgREST requests: authenticated
  15 s / idle 30 s, anon 5 s / idle 15 s. Role settings live in `rolconfig`
  and apply at login; `SET ROLE` does **not** re-apply them (assert via
  `pg_roles.rolconfig`, not `current_setting`).
- CI builds the **release** APK too (R8/tree-shaking); a local release build
  passes (`app-release.apk`). R8 rules live in `android/app/proguard-rules.pro`.
- Test count at this point: 930.

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

### Production hardening (2026-10-29)

- `0069_scale_hardening.sql`: `pg_trgm` GIN on `vehicles.plate` (records/history
  use `ILIKE '%term%'`), lot/entry, pass/lot/end, active-reservation and
  notification/lot/user/date indexes, plus guarded checks for pass windows,
  pass amounts and `amount_charged`. `rpc_test.sql` asserts the indexes and the
  three constraints; the local DB was migrated and the indexes verified.
- `RouteErrorPage` + `go_router` `errorBuilder` replace raw router exceptions on
  unknown/deep-link paths, with a home CTA (router test).
- `/about` shows `FLUTTER_BUILD_NAME (FLUTTER_BUILD_NUMBER)`.
- RLS guard: `rpc_test.sql` requires RLS on every `public` table; `0070` locks
  `public.schema_migrations` (RLS on, no anon/authenticated grants).
- Ops hardening (2): `0071` schedules audit/WhatsApp retention in pg_cron (the
  host cron already called them); `BACKUP_KEEP=N` prunes old archives; CI now
  builds the Android debug APK as well as web.
- Ops hardening: `supabase/backup.sh` validates the dump with `pg_restore
  --list` and writes `SHA256SUMS`; `tool/evidence-web.nginx.conf` sends
  nosniff/referrer/frame/Permissions-Policy headers plus gzip (headers are
  repeated in the asset location because nginx drops inherited add_header).
- Coverage ratchet: `flutter test --coverage` + `dart run
  tool/check_coverage.dart` (global 70, application 90, domain 35,
  infrastructure 25; generated/l10n ignored). CI pins Flutter 3.50.0-0.1.pre,
  the local beta.
- `docs/production-readiness.md` is the go-live checklist (SLOs, infra, schema
  guards, security, resilience, observability, release/rollback, limits);
  linked from `docs/README.md` and `AGENTS.md`.

### UI batches (2026-10-29)

- Settlement: segmented payment methods, tonal cash panel (`Money.format` +
  currency symbol), inline error banner and `Money.parse` for discounts.
  Notifications add an app-bar type filter (`monthly_pass` covers expiring and
  renewed).
- Reports: presets + date picker + "all sites" chip in one `FilterBar` with the
  period as summary. Its test scrolls in 40 px `jumpTo` steps: the lazy list
  disposes rows and overshooting makes `scrollUntilVisible` throw "No element".
- Shift: opening form header with hint and currency prefix; closed card with a
  balanced/warning chip and expected/counted `MetricCard`s. A 4-across home KPI
  grid was tried and reverted (cards overflow their internal rows at the 1080
  content cap).
- Diagnostics: health banner above the metrics (`alerts == 0` → success, else
  "N puntos requieren atención"). It uses `health_and_safety_outlined` /
  `report_problem_outlined` because the a11y test counts
  `warning_amber_outlined`.
- `DialogHeader` (tonal icon + title + optional hint) titles the user, vehicle,
  tariff, reservation, pass, site and capacity dialogs.
- Public developer page at `/about` (`route_access.aboutPath`, allowed in
  `authRedirect`): DevPaul identity, links and authorship/rights notices; logo
  at `assets/branding/devpaul.png` (512 px, registered in pubspec). Entry
  points: drawer, desktop sidebar info button (`aboutDeveloper` tooltip) and
  login footer; links use the injectable `AboutLinkLauncher` seam.
- Test count: 835.
- **Centering fix (2026-10-28)**: `CenteredScrollable` now enforces
  `minWidth` equal to the viewport, otherwise its scroll child shrank to the
  widest line and the empty/error block drifted left on wide pages (the
  monthly-pass/reservation screenshots). Covered by the UI-kit test that
  asserts icon/message/action share the viewport center. Test count 823.
- **Notifications/shift history (2026-10-28)**: notification metadata appends a
  localized type label (`notifType*` keys); shift history cards use a
  balanced/warning avatar and a two-line subtitle. Test count stays 822.
- **Public pages/history (2026-10-28)**: `/policies` has a brand hero plus
  numbered clauses (split the rendered policy by lines; first line is the
  heading), `/evidence` gates the plate in a centered card, both load with
  `SkeletonCardList`; vehicle history joins session cards with a timeline rail
  (open dot uses `tertiary`, closed `primary`).
- **Check-in/settings (2026-10-28)**: the check-in form is sectioned
  (vehicle/evidence) and starts with a pulse chip (`parkedCount` + active
  reservations); the submit button is an icon button with a 48 dp target.
  Settings adds a horizontal chip index on ≥ 720 px that uses
  `Scrollable.ensureVisible` with per-section `GlobalKey`s. Test count 822.
- **Core flows polish (2026-10-28)**: check-out wraps search + QR in a
  `FilterBar` with the inside count and renders sessions as cards (the leading
  avatar is hidden below 600 px because it squeezed the status chips);
  `StatusChip` truncates its label so chips never overflow; the empty lot has a
  title/hint/check-in CTA; settings opens with a branded header card. Test
  count 821.
- **Dashboard/list polish round 2 (2026-10-28)**: reports and diagnostics use
  `MetricCard` summaries and `SectionHeader` blocks (diagnostics labels were
  split into summary vs section so tests can tell them apart);
  categories/tariffs/vehicles/sites are cards with tonal avatars (vehicles add
  a `FilterBar` count); contact is a card; the open shift shows a status chip.
  Lazy `ListView`s mean bottom sections need a scroll/tall viewport in tests.
- **Preferences placement (2026-10-28)**: the phone app bar only carries the
  notification bell and `SyncBadge`. Language/appearance/sign-out live at the
  end of the drawer list (`_DrawerPreferences`, bottom-sheet pickers, current
  value as subtitle) and the drawer header has a close (X) button; on desktop
  they sit in the sidebar footer via `_Preferences`. `pumpApp` now accepts a
  `themeCubit` so tests can assert those rows; without the cubits the rows are
  hidden, so isolated pages stay testable.
- **Scan shortcut (2026-10-28)**: the shell FAB is hidden whenever
  `isManagementLocation(location)` (any `managementDestinations` entry) so
  admin/reference screens stay clean; it remains on home, check-in/out,
  records, notifications, contact and vehicle history.
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

## Dev environment running (2026-10-29)

- Backend: `docker compose up -d` from the repo root; all services healthy,
  gateway on <http://localhost:8017> (`API_GW_HTTP_PORT` in `.env`) and Studio
  loopback-only on <http://localhost:3000>;
  migrations `0001`-`0068` applied.
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
- **2026-10-30 (resolved): the phone was not "broken Wi-Fi"**. Its DHCP lease
  moved from `192.168.0.2` to `192.168.0.8` and wireless debugging changed
  port, which silently killed the `adb reverse` tunnel the old APK depended on.
  Verified with ping/nc from the phone: Wi-Fi and `192.168.0.17:8017` work.
  The APK is now built with `SUPABASE_URL=http://192.168.0.17:8017` (LAN), so
  it no longer needs adb after install. `tool/run-android.sh` defaults to LAN;
  `ANDROID_MODE=localhost` keeps the reverse mode. `tool/android-doctor.sh`
  prints device/host/port state. Reconnect adb only to reinstall.
- **Gateway root / Studio (2026-11-05)**: opening `http://<lan-ip>:8017/` used
  to proxy Supabase Studio through the global basic-auth filter, so browsers
  asked for a username/password ("connection not private" is just HTTP on the
  LAN). The root route now redirects (307, `port_redirect: 8080`) to the app on
  the same host, with basic auth disabled; Studio is published only on
  `127.0.0.1:3000`. API routes
  (`/auth`, `/rest`, `/storage`, `/realtime`, `/functions`) are unchanged.
- **One-command demo (2026-11-03)**: `sh tool/dev-up.sh` starts compose +
  migrations, recreates the public host, starts Chrome dev (unless already
  running) and installs/launches the LAN APK on the first adb device.
  `ANDROID=0` skips the phone; `ANDROID_BUILD=1` rebuilds first. It prints the
  LAN web/API URLs and the login.
- **Evidence host**: `parking-evidence-web` is not a compose service; after a
  Docker/host restart recreate it with `sh tool/run-evidence-web.sh` (binds the
  LAN IP, since 127.0.0.1:8080 belongs to another project, `restart:
  unless-stopped`).
- **Phone over wireless adb** (the port changes on every reconnect; last
  seen 2026-11-05 at `192.168.0.2:34591`). The LAN APK does not need `adb
  reverse`; reinstall with `sh tool/dev-up.sh` / `ANDROID_BUILD=1`. If it drops
  again, `adb devices` first, then reconnect by IP:port.
- Chrome dev app is running with `APP_URL=http://192.168.0.17:8080`; the public
  bundle is served by Docker (restart `parking-evidence-web` after a public
  build). **Port 8080 on `127.0.0.1` belongs to another local project**
  (`xuper_flutter/tools/local_proxy.js`), so the container binds
  `192.168.0.17:8080:80`: use the LAN URL for evidence/policies, not
  `http://localhost:8080`. Recreate it with that bind after a Docker restart.

## Android over adb

- `tool/run-android.sh [serial]` re-applies `adb reverse tcp:8017 tcp:8017` and
  runs Flutter with `SUPABASE_URL=http://localhost:8017`. **Wireless adb
  reconnects on a new port and drops every reverse mapping** — the app then
  cannot reach the backend until the reverse is re-applied. No `ufw` rule is
  involved on that path; only a LAN URL needs `ufw allow 8017/tcp`.
- `adb shell curl -s -o /dev/null -w '%{http_code}' http://localhost:8017/rest/v1/`
  must answer `401` (reachable); `000` means the tunnel is missing.
- The wireless serial changes on every reconnect (`192.168.0.2:<port>`): read it
  from `adb devices` instead of hardcoding it. `adb exec-out screencap -p`
  works while the phone is unlocked; a black PNG means the screen is locked.
  Also verify with `dumpsys window | grep mFocusedApp` + the REST probe.

## Boot order (fresh installs)

- `main()` renders a branded splash while `auth.restore()` reads the Hive
  session and loads memberships; the real app replaces it when that resolves.
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

- `flutter test`: 993 passed (+1 live-stack integration skipped); `flutter
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
