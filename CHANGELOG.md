# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project aims at [Semantic Versioning](https://semver.org) once it
publishes its first release. **The project is pre-1.0: there are no tagged
releases yet; everything below is unreleased work on `feature/supabase`.**

## [Unreleased] — 2026-11 (app reliability and operator UX)

### Fixed
- **Web deep links were lost**: the bootstrap splash pushed its own route to
  the browser history before the router existed, so `/reserve?lot=1`,
  `/policies?lot=1` and the receipt `/evidence?…` links all landed on
  `/login`. `main()` now captures the browser URL (`initialRouteFrom`) before
  the first frame and hands it to the router; mobile still starts home.
- Exported PDFs no longer contain a missing glyph where the report/records
  date range used an em dash: the built-in Helvetica font has no em/en dash,
  so PDFs now use `Formatters.pdfDateRange` (ASCII hyphen). On-screen labels
  keep the typographic dash.
- Reports: the variation line ("vs previous period") now wraps on narrow
  screens instead of overflowing its summary card.
- Capacity rows (home capacity card) no longer overflow with large
  accessibility text: the label clamps to two lines and the counter is
  flexible and ellipsized.
- Device preferences (auto-lock, language, appearance, sidebar state) were lost
  on a cold start: `HiveKeyValueStore.get` is synchronous and only reads open
  boxes, and the `preferences` box was opened only on the first `put`. `init()`
  now opens it, so auto-lock stays at the chosen value across app restarts.
- Opening the API gateway root (`http://<lan-ip>:8017/`) no longer triggers a
  Supabase Studio basic-auth prompt: it redirects (307) to the app on port 8080
  of the same host, and Studio is published only on `127.0.0.1:3000`. API
  routes are unchanged. (HTTP on the LAN still shows "not private"; production
  uses HTTPS.)
- Shift close reads counted cash in the site currency (USD no longer stored as cents).
- Outbox retries after network/server failures (15s→30s→60s) instead of
  stalling or dead-lettering; drains right after enqueue.
- PostgREST 5xx, serialization/deadlock/timeout and `PGRST303` are retryable
  or auth failures; a GoTrue sign-out surfaces the expired-session banner.
- Offline settings edits replay into the lot they were made for; dashboard and
  branding drop stale results after a lot switch.
- Receipts carry cash received/change/card type; open sessions carry plate,
  photo count and left keys (no full vehicles download).
- Pass/reservation success survives a failed list refresh; queued check-out
  receipts show the real plate and entry time; evidence names are deterministic.
- Lost ticket charges `lost_ticket_amount` and disables the monthly-pass method.
- Android release build: R8 keep rules for the optional ML Kit scripts.

### Added

- **Home trend card**: `0080_dashboard_trend` adds `dashboard_trend(p_days)`, a
  lot-scoped, operator-callable daily series (revenue, entries, exits) in the
  site's business timezone. Days without movement come back as zeroes, so the
  home dashboard paints the last 7 days as bars scaled to the best day, with
  weekly revenue/entries/exits totals, a quiet-week message, a loading skeleton
  and an admin shortcut to reports.
- **Week-over-week insight**: the home trend now loads fourteen days and
  compares the current week with the previous one (`+18 %` in success tone,
  warning tone when revenue drops, "same as last week" when flat). It is
  hidden when the previous week has no revenue to compare against.
- **Bay maintenance history**: taking a bay out of service (or bringing it
  back) now asks for an optional reason (3–200 characters) and records who,
  when and why in `parking_spot_events` (`0081`): lot-scoped RLS, written by
  `save_parking_spot` in the same transaction that changes the status, so the
  log cannot drift. The bay editor shows **Ver historial** with the last
  transitions (skeleton, empty and retry states); operators can read it, only
  admins can change a bay. Any map edit refreshes the home board.
- **Offline dashboard**: the home keeps the last successful occupancy, today,
  trend and capacity snapshot on the device (versioned JSON, one entry per
  site). When a load fails the operator still sees those KPIs with a
  "Sin conexión · datos guardados de las HH:mm" notice and a retry, instead of
  an empty dashboard; the live space board and inside list are hidden because
  they would be stale. A partial load (one RPC failed) never overwrites a
  complete snapshot.
- **Hourly traffic on reports**: `0082` adds `report_hourly_traffic(start,
  end)` (admin, lot-scoped, business timezone) with entries and exits for all
  24 hours. The reports screen renders a compact hour grid sized for the
  screen (4/6/8 columns), scaled to the busiest entry hour, with a peak-hour
  summary, per-hour tooltip/semantics, an empty state and a legend. A failed
  hourly RPC degrades to the empty grid without failing the report.
- **Month presets and hourly exports**: the report range now offers **Este
  mes** and **Mes anterior** with calendar boundaries, shown as chips in the
  filter bar (they wrap on phones instead of squeezing a segmented button).
  The CSV gains `hourly_entries`/`hourly_exits` raw rows and the PDF a
  "Tráfico por hora" table, both limited to hours with movement.
- **Audit search**: the audit screen has a debounced free-text field matching
  the entity id, table, actor (username/display name), plate and name — for
  example a plate from a support call — combinable with the table, actor and
  date filters. `0083` recreates `list_audit_log` with `p_search` and fixes the
  old ordering bug where the page limit was applied before the actor filter.
- **In-app evidence viewer**: `0084` exposes `photo_count` per session in
  `vehicle_history` (scoped to the active lot). The vehicle history now offers
  "Ver evidencias (N)" when a session has photos or videos; a bottom sheet
  signs Storage URLs on demand and shows a photo grid (tap to zoom) and video
  tiles with a play action, with loading, empty and error+retry states. Listing
  stays protected by the lot RLS; a file whose signature fails is kept as an
  unavailable tile instead of hiding the row.
- **Evidence from check-out**: the open-session row shows an "Evidencias (N)"
  chip when the car has photos/videos, so an operator can review the entry
  evidence without leaving the exit flow. It opens the same viewer and wraps
  with the other status chips on phones.
- **Evidence from records**: `0086` adds the photo count to `session_records`,
  so each activity-log row with evidence offers "Evidencias (N)" under its
  times. The log reuses the same viewer (signed URLs, zoom, video, retry); the
  evidence is only queried when the operator taps it.
- **First-steps checklist**: `0085` adds `lot_setup_status()` with the active
  site's categories, active tariffs, capacity/active bays and identity flags.
  Admins of a new site see a **Primeros pasos** card on the home with a
  4-step progress bar (categories, tariffs, capacity/map, address + phone) and
  a shortcut to the screen that fixes each step; operators never see it and it
  hides once the site is complete. A failed status call hides the card instead
  of showing a false "not configured" state.
- **Daily revenue chart in the PDF**: the exported report draws a compact bar
  chart of revenue by day above the table (scaled to the best day, with the
  first and last dates underneath), so the period's shape is visible without
  reading every row. Quiet periods keep zero-height bars and an empty range
  skips the chart.
- **Hourly chart in the PDF**: the hourly section now also draws 24 bars
  scaled to the busiest entry hour, with 00/06/12/18/23 labels above the
  table. Exits stay in the table, so the chart answers "when is the gate
  busiest?" at a glance.
- **Branded startup**: the app shows a splash (logo + loading) for the first
  frame while the session and lot memberships restore, instead of waiting on
  the network before the first `runApp` (a blank screen on slow links). The
  real app replaces the splash once the restore resolves; corrupt local
  storage falls back to login instead of leaving the splash forever.
- **Search vehicles by owner**: the registry search now matches the plate, the
  owner name or the owner phone (`plate.ilike` OR `owner_name.ilike` OR
  `owner_phone.ilike`, quoted so names with spaces/commas work), and the
  offline cache filter mirrors it. The field label/hint say so; owner data was
  already captured, so no schema change was needed.
- **Owner search in monthly passes**: the passes search now also matches the
  owner name or phone, for both passes and pending charges (resolved through
  the loaded vehicles); the empty state and count follow the same filter.
- **History from the registry**: each vehicle row has a "Ver historial"
  action (48 dp) that opens `/history?plate=…`, so finding a car by owner name
  or phone and reviewing its visits takes one tap. The row fits a 400 px phone
  with the three actions.
- **Check-in from the history**: a vehicle with no open session offers
  "Registrar entrada" in its history, opening `/check-in?plate=…` with the
  plate prefilled; a vehicle already inside keeps "Cobrar en caja".
- **Public booking page**: `/reserve?lot=<id>` is a public, mobile-first page
  served by the self-hosted web host. It shows the lot identity and real
  availability per vehicle category (`public_availability`, anon), lets the
  customer pick a category and duration (1/2/4/8 h), and creates a hold with
  plate, **name** and **mobile phone** (`public_create_reservation`).
  The confirmation carries the reservation code, until, lot contact, call and
  WhatsApp actions. Guards: 10-minute minimum / 24-hour maximum window, one
  active hold per plate, two active public holds per phone, invalid plates
  rejected, the name is required and the phone has to be a Colombian mobile
  (10 digits starting with 3, optional +57, stored without the country code),
  and a full category/group is refused. The capacity rules are
  shared with the operator path, and anon cannot read the reservation table.
  The page is linked from the public policy page and the evidence page.
- **Scheduled jobs actually run**: `docker-compose.yml` gains `supabase-jobs`,
  a small container that calls the retention/notification functions every 5
  minutes (expire unused holds, renew passes, overstay and expiring-pass
  alerts, purge old notifications/audit/idempotency/WhatsApp rows) and
  dispatches pending push/WhatsApp messages. Neither the stock Postgres image
  (no pg_cron) nor this host (no cron daemon) ran them before, so stale holds
  stayed `active` forever and push never left the queue.
- **Directions and live numbers**: the `/reserve` hero offers "Cómo llegar"
  (Google Maps search for the lot address, `core/utils/maps_launcher.dart`)
  next to the phone and WhatsApp actions, and the availability re-reads itself
  every minute without flashing the skeleton, so a customer deciding on the
  page never reads stale numbers.
- **The grace window is a setting**: "Tolerancia de reservas (min)" in Ajustes
  (0..120, default 15) is the single value the capacity check, public
  availability, check-in and the board read. `0` disables it: the hold stops
  counting exactly on time.
- **One owner for the grace window**: the reservations board now loads through
  `list_active_reservations()`, which applies `reservation_grace()` and
  returns an `in_grace` flag. The Dart copy of the 15 minutes (and the
  PostgREST date arithmetic) is gone, so changing the window in SQL can no
  longer disagree with the app.
- **A full lot says so**: when every vehicle type is at capacity, `/reserve`
  hides the booking form (a form nobody can submit is a dead end) and shows
  "No hay cupo en este momento" with the call/WhatsApp actions; the code
  lookup stays, so a returning customer can free their own hold and the
  one-minute refresh brings the form back as soon as a spot opens.
- **The customer gets the booking on WhatsApp**: with "automated WhatsApp" on,
  a public hold queues a `reservation_confirmed` message (name, plate, time,
  lot) that `whatsapp-dispatch` sends once the Meta token and the approved
  template exist — nothing is sent while the switch is off. The queue now
  ages out pending rows too (90 days), so a lot without credentials does not
  accumulate them forever.
- **Grace window for late customers**: `reservation_grace()` (15 minutes) is
  honoured by the shared capacity check, `public_availability` and `check_in`,
  so a customer who arrives a few minutes late still has the space: the hold
  keeps counting until the window ends and check-in turns it into `used`
  instead of leaving a stale row. The board keeps those holds visible with an
  "En tolerancia" chip.
- **The reservation code reaches reception**: each card on the reservations
  board shows the code the customer was given (`#7 · Hasta 20:35`) and the
  search matches it, so the front desk can act on the number printed on the
  confirmation instead of asking for the plate. "Registrar entrada" on the
  card still opens check-in with the plate prefilled.
- **"Web only" filter**: the reservations board can show just the holds that
  came from the public page, next to "por vencer", and the filter chip resets
  with "limpiar filtros".
- **Prices on the public page**: each vehicle card shows the lot's real
  hourly tariff ("Desde $5.000/hora") from `tariffs` (`type='hourly'`,
  active), formatted with the lot currency; a category without a tariff says
  "Tarifa en recepción" instead of inventing a number.
- **"Already booked?" lookup**: the public page ends with a code + mobile form
  (`public_reservation_lookup`, anon) that retrieves the active hold and lets
  the customer cancel it without the confirmation screen. It returns null for
  a wrong code/phone, an expired hold or an operator hold, so only the
  customer's own visible booking is exposed.
- **Customers can give the space back**: the `/reserve` confirmation offers
  "Cancelar reserva" (with a confirmation dialog) and ends on a
  "Reserva cancelada" screen. `public_cancel_reservation(code, plate, phone)`
  (anon) only cancels `source = 'public'` holds and needs all three values, so
  a plate alone is not enough to free someone else's space; availability
  refreshes right away. The hold is marked `cancelled` (history is kept).
- **Operators run the reservations board**: `/reservations` joined the operator
  allowlist (with its "Ver reservas" shortcut on the home dashboard), because
  whoever is at the desk hands the web bookings to the customer. The management
  section on Home now lists only the sections the signed-in role may use.
- **Who booked from the web**: the reservations board now shows the customer's
  name and mobile, a "Web" badge for holds created on `/reserve`, and one-tap
  call/WhatsApp actions, so the front desk can reach the person before they
  arrive. Search matches the plate, the name or the phone.
- **Web bookings alert the lot**: every public hold leaves a
  `public_reservation` notification for every active member of the lot (admins
  and operators, who now work the board), with the plate, the customer and the
  expiry in the lot's timezone; tapping it opens the reservations board.
  Deduplicated per reservation and user.
- **Emergency action**: a red police icon in every app bar (and an entry in the
  desktop sidebar footer and the phone drawer) opens a one-tap panel with the
  site location, the nearest police quadrant and a large **Call now** button.
  The quadrant number is configured in **Ajustes → Emergencias**
  (`parking_settings.police_phone` in `0079`, 3–15 digits). Until it is set,
  the panel falls back to the national emergency line **123** and admins get a
  shortcut to settings; operators see a note to ask the administrator.
- Vehicles now keep **optional owner details**: a full name (`owner_name`) and
  the existing phone. Admins can set/edit them from the vehicle list or the
  vehicle history, and both are optional (a plate without them works as
  before). `0078` adds the column + validation, returns `owner_name` from
  `update_vehicle_flags`/`vehicle_history`, and the history offers a single
  "Datos del propietario" dialog for name + phone (useful for monthly passes or
  when an owner leaves the keys). The monthly-pass tile shows the owner name.
- Monthly passes now take the amount from the **tariffs list**: the dialog
  prefills the active `monthly` tariff of the selected vehicle's category,
  follows the vehicle change, and offers "Usar tarifa mensual (…)" when editing.
  `MonthlyPassesCubit` loads tariffs alongside vehicles; no manual retyping.
- About copy now presents Paul as a **Systems Engineer with 7+ years in web and
  mobile development**, explicitly including backend/database/infrastructure,
  instead of "Flutter apps only"; English and Spanish updated.
- Navigation cleanup: the sidebar's preference icon row is gone. The footer now
  has **Ajustes** (language, appearance, auto-lock, help) and **Acerca de**
  entries; the mobile drawer mirrors them. `PreferencesPage` lives at
  `/preferences` and is available to operators. About now lists both
  developers (Paul Realpe/DevPaul and Jimmy Realpe) with their sites.
- The public evidence page now carries the site's identity and contact: name,
  logo (public branding bucket URL), address/schedule, a **Call** button and a
  direct **WhatsApp** button with a message prefilled with the plate. Data comes
  in the `public-evidence` response (`lot` object), so the customer needs a
  single request and no login.
- Public evidence QR now shows the parked time and the price: `0077` adds
  `public_session_summary(session, plate)` (plate-keyed, anon callable) with
  duration, currency, current fare/charged amount and pass coverage; the
  `public-evidence` function returns it and the public page renders two metric
  cards ("Tiempo en el parqueadero" / "Valor estimado" or "Total cobrado").
  `Money.formatAs` formats with the summary currency without changing the
  ambient site currency.
- Contract tests for the client/server JSON shapes (vehicle, user, category,
  monthly pass, parking session, lot member) and domain parsers (public lot
  profile, pass payments, today summary, session records, lots). Coverage
  floors raised: global 78 %, domain 47 %, infrastructure 38 % (application
  stays 90 %).
- Help center (`/help`, operators included): searchable, localized how-tos for
  opening a shift, charging, reprinting, reconciliation, cash movements,
  check-in evidence, reservations, passes, offline work, auto-lock and update
  notices. Reached from the drawer and the desktop sidebar.
- Minimum app version (`0076_min_app_version.sql`): each site can set
  `min_app_version` (validated `major.minor[.patch]`, exposed by
  `public_lot_profile`). Older builds see a persistent, localized update banner
  above the content instead of failing with contract mismatches.
- Idle lock: after a configurable period without pointer/keyboard activity the
  app hides behind a PIN screen (GoTrue re-login, 5 attempts then sign-out).
  The timeout is a device preference (off/1/5/15/30 min, default 5) chosen from
  the drawer or the desktop sidebar; the session and outbox are preserved.
- Vehicles: admins can **edit** a vehicle's category, brand and color from the
  list (plate stays immutable as the ticket/history key). The repository update
  path existed but was unusable because `0075_vehicle_update_grant.sql` was
  missing; the grant is added and RLS still restricts writes to admins.

### Hardened

- Check-in no longer downloads the 200-vehicle suggestion page on open: known
  plates load when the operator types the second character (a failed attempt
  is remembered so typing does not hammer the endpoint). On open it also
  refreshes only the **capacity snapshot** when the shell already has the
  dashboard loaded (one request instead of the six/seven KPI reads); a
  successful entry still does the full refresh so home counters stay current.
- Shift, reservations and monthly-pass screens load their independent reads
  concurrently instead of chaining round trips: current shift + history,
  active reservations + categories, and passes + pending payments + vehicles +
  tariffs now start together (each keeping its own failure handling). Tests
  gate the first call and assert the second already started.
- Home dashboard reads are concurrent: occupancy first, then today, trend,
  capacity, the space board and the inside list run together (each degrading on
  its own), instead of six serial round trips.
- Ops: optional `BACKUP_REMOTE` offsite copy with `rclone` (job fails if the
  copy fails), backup-age and disk warnings in `healthcheck.sh`, and systemd
  units/timers for healthcheck, cron and nightly backups
  (`docs/operations-systemd.md`).
- Supabase traffic now goes through `ResilientHttpClient`: a 20 s timeout per
  request (storage uploads exempt), automatic retries for idempotent
  GET/HEAD on timeouts, connection errors and 502/503/504, and **no transport
  retries for writes** (the RPC/outbox layer owns idempotency). Timeouts,
  retries and failed requests are counted and shown in `/diagnostics` under
  "Client network".
- `tool/dev-up.sh` brings the whole demo up with one command (stack, migrations,
  public host, Chrome dev, LAN APK on the connected phone).
- `0074_statement_timeouts.sql`: PostgREST roles get `statement_timeout`
  (15 s authenticated, 5 s anon) and `idle_in_transaction_session_timeout`
  (30 s / 15 s), so a runaway request cannot pin a connection. The SQL suite
  asserts the role settings.
- CI also builds a **release** APK (tree-shaking/R8) after the debug build, so
  release-only failures are caught before shipping.

### Changed (UX)
- The home KPI grid paints `SkeletonCard` placeholders (shared pulse, static
  under reduce motion) while the first dashboard load is in flight, instead of
  mixing a progress bar with cards that appeared one by one.
- Charge rows show a busy spinner, ignore double taps and are fully tappable.
- Payment dialog: live total after discount, per-field errors, "Cobrar $X"
  button, "Exacto" and banknote shortcuts for cash received.
- Check-in: sticky submit bar, category chips (≤5), "Escanear placa", charge
  shortcut when the plate is already inside; free bays open check-in for that bay.
- Receipt summary prints in one tap; keyboard-safe cash count sheet and shift
  dialogs; 48dp icon targets; slot cells scale with text size.

## [Unreleased] — 2026-11 (SQL integrity fixes `0072`/`0073`)

### Fixed

- **Billing (`0072_billing_integrity.sql`)**: `fare_breakdown` rounds the stay
  up to whole hours **once** (`ceil(total_secs / 3600)`) and spreads them over
  the day/night buckets of each calendar day by largest remainder
  (`allocate_billable_hours`, ties to the earliest bucket); the daily cap still
  applies per day. 23:59→00:01, 23:30→00:30 and 17:58→18:03 (night start) now
  bill one hour. Output shape unchanged.
- Tariffs must belong to their category's lot (composite FK
  `tariffs(category_id, lot_id) → categories(id, lot_id)`); `fare_breakdown`
  only reads tariffs of the category's lot.
- `has_pass` in `check_out`, `check_out_preview`, `slot_board` and
  `open_sessions_view` only counts passes of the session's lot.
- Lost ticket: the fee comes from the session lot's settings (was lot 1);
  `gross = greatest(fare, lost_ticket_fee | daily tariff | 0)`; a
  `monthly_pass` method is rejected with `LostTicketPassMethodError`.
  `check_out_preview` adds `lost_ticket_amount` (minor units).
- Offline exits older than 12 h raise `StaleExitTimeError`; the server close
  time is stored in the new `parking_sessions.closed_recorded_at`.
- **Shifts (`0072`/`0073`)**: `check_out`, `add_cash_movement` and
  `register_pass_payment` attach only to the actor's **open** shift and lock it
  `FOR SHARE`, so `close_shift` (`FOR UPDATE`) waits and counts them. Replays
  after a close go to the current open shift, else to no shift.
  `shift_totals` authorizes lot admins (`is_lot_admin`), fixing `list_shifts`
  for them.
- **Capacity (`0073`)**: `create_reservation` takes check-in's advisory locks
  in the same order (group via `category_group(name)`, then category),
  avoiding oversell and ABBA deadlocks.
- **Passes (`0073`)**: `renew_monthly_passes` uses each lot's business date,
  renews only passes whose `end_date` is before local today (a pass stays
  valid on its last day) and keeps calendar-month periods
  (`pass_period_months`); other periods keep their day count.
- **Evidence (`0073`)**: `check_in` requires every photo/video path to be an
  `evidence` object owned by the caller and not already referenced
  (`EvidenceNotFoundError` / `EvidenceAlreadyUsedError`);
  `evidence_photos(file_path)` is now unique.
- **Notifications (`0073`)**: `close_shift` and `notify_session_event` format
  amounts in the lot currency (`format_money`: `$5.000` COP, `US$1,234.50`
  USD), matching `Money.format`.

## [Unreleased] — 2026-10

### Added

**Production hardening**

- `0069_scale_hardening.sql`: `pg_trgm` + a GIN index for plate search, hot-path
  composite indexes (sessions per lot/entry, passes per lot/end, active
  reservations, notifications per lot/user/date) and guarded invariants
  (`end_date >= start_date`, non-negative pass and charged amounts). SQL suite
  covers the indexes and the three constraints.
- Friendly `RouteErrorPage` for unknown or broken deep links, with a one-tap
  return home (router `errorBuilder` + test).
- RLS guard: the SQL suite fails when any `public` table lacks RLS;
  `0070_lock_migrations_table.sql` enables it on the runner's
  `schema_migrations` and revokes `anon`/`authenticated` access.
- Branded first paint: the Android cold-start window uses the brand background
  with the app mark centred, and the web build shows a dark splash with the
  icon until Flutter's first frame (removed automatically).
- `0071_retention_schedule.sql` completes the `pg_cron` schedule (audit 365 d,
  WhatsApp 90 d); the host cron fallback already called both functions.
- `BACKUP_KEEP=N` prunes old archives while keeping the newest N.
- CI now compiles the Android debug APK (with placeholder defines) in addition
  to the release web bundle.
- Backups fail if `pg_restore --list` rejects the dump, and each backup ships
  `SHA256SUMS` for integrity checks.
- The public static host sends baseline security headers and gzip for
  JS/wasm/JSON/SVG.
- CI now runs `flutter test --coverage` + `dart run tool/check_coverage.dart`
  (global ≥ 70 %, application ≥ 90 %, domain/infrastructure ratcheted) and pins
  the same Flutter beta as local (3.50.0-0.1.pre).
- `/about` shows the build name and number (`FLUTTER_BUILD_NAME`/`NUMBER`).
- `docs/production-readiness.md`: SLO targets, infrastructure, schema guards,
  security, resilience, observability, release checklist and known limits.

**UI/UX pass across every module**

- Create/edit dialogs (user, vehicle, tariff, reservation, monthly pass, site,
  category capacity) share a `DialogHeader` with a tonal icon, title and hint.
- Diagnostics opens with a health banner: a calm "Todo en orden" block or the
  number of items needing attention, above the summary metrics.
- Shift: the opening form leads with a tonal lock, title and hint, the amount
  field shows the currency symbol and the button keeps a 48 dp target; the
  closed-shift card shows balanced/warning icon and chip plus expected/counted
  metric cards before the difference row.
- Reports: the range presets, date picker and all-sites toggle live in one
  filter card with the selected period as summary (matching the other lists).
- Dialog layout guard: a 400 px regression test pumps the vehicle, tariff,
  user, site, reservation, monthly-pass and capacity dialogs and fails on any
  layout exception (the class of bug behind the squeezed payment methods).
- Dev networking: `tool/run-android.sh` defaults to LAN mode (no `adb reverse`
  dependency), `tool/android-doctor.sh` prints host/device/port diagnostics and
  `tool/run-evidence-web.sh` recreates the public host after a restart.
- Expired sessions now explain themselves: a 401 emits
  `AuthUnauthenticated(expired: true)` and the login screen shows a live-region
  "session expired" banner instead of a silent return.
- Settlement dialog: the four payment methods are wrapping `ChoiceChip`s, not a
  segmented control — a segmented row squeezed and overflowed on phones with
  rotated labels (fixed after a device screenshot).
- Settlement dialog: payment methods are a segmented choice, cash sits in a
  tonal panel with a large change figure, errors use an inline banner, the
  currency symbol/format come from `Money` (no hardcoded `$`, USD decimals
  parse correctly) and the confirm action has an icon.
- Notifications gain a type filter (all, check-in, check-out, passes, overstay,
  shift) in the app bar, with a clear-filters empty state.
- About the developer (`/about`, public): DevPaul identity with the capybara
  logo, role, bio, website/GitHub/LinkedIn/Instagram links, the app summary
  with its version, and the "Hecho por DevPaul" / "© 2026 DevPaul. All rights
  reserved." notices (hero chip, app card and page footer). Linked from the
  drawer, the desktop sidebar and the login footer.
- Empty/error blocks are truly centered on wide pages: `CenteredScrollable`
  now fills the available width instead of shrink-wrapping to the widest line
  (monthly passes, reservations, history and every other empty state).
- Notifications label each row with its type (check-in, check-out, pass,
  overstay, shift) next to the timestamp.
- Shift history rows are cards with a balanced/warning avatar and separate
  sales/difference lines (difference highlighted when it does not balance).
- Public pages: `/policies` opens with a branded identity card and renders the
  contract as numbered clauses; the `/evidence` gate is a centered card with a
  tonal lock and a 48 dp unlock button. Both use card skeletons while loading.
- Vehicle history renders movements on a timeline rail (dot per visit, open
  stays highlighted).
- Check-in: the form is split into "Vehículo" and "Evidencia" sections with
  hints, a live pulse chip (`N dentro` / active holds) above the plate field,
  and the submit button gains an icon and a 48 dp target.
- Settings: wide screens get a section chip index (identity, spaces, evidence,
  messaging, preferences, legal) that scrolls to each block.
- Check-out: the plate search and QR button sit in a filter card with the
  "N inside" count, open sessions render as cards with a long-stay avatar and
  the empty lot explains the next step with a check-in CTA.
- Settings opens with a branded header card (tonal logo, site name and logo
  action); chip labels truncate instead of overflowing on narrow rows.
- Reports: total revenue opens as a primary metric card with the period and
  previous-period delta; pass revenue, discounts, WhatsApp counters and
  occupancy are metric cards too, and every block uses the shared section
  header.
- Diagnostics: top metrics for open sessions, pending queue and alerts, section
  headers with divided rows, warning chips and tonal avatars on WhatsApp/error
  rows.
- Categories, tariffs, vehicles and sites render as cards with tonal avatars;
  vehicles add a filter bar with the result count.
- Contact is a branded card plus tappable rows with tonal icon avatars; the open
  shift card shows its status chip.
- Mobile app bar keeps only the notification bell and sync badge. Language,
  appearance and sign-out moved to the drawer (with the current value as
  subtitle and a bottom sheet to switch), and the drawer header gained an
  explicit close button. On desktop the same preferences sit in the sidebar
  footer next to the account card.
- The scan-to-check-out shortcut is now hidden on every management route
  (vehicles, tariffs, categories, diagnostics, audit, sites, reservations,
  passes, users, reports, settings); it stays on the operator screens.
- Side navigation: branded logo tile and role dot, hairline under the header,
  rounded nav pills with a primary accent bar for the active page, denser
  nested management rows under a guide line, a count badge and rotating
  chevron on the management accordion, active-site card with icon tile and a
  user card with gradient avatar, online dot and compact logout; the collapsed
  rail keeps tonal icon squares, tooltips and the avatar. Tokens and
  `ColorScheme` only.
- Sign-in screen: on wide screens it splits into a tonal brand panel (identity,
  tagline and the three operator jobs) and a bordered form card; phones keep
  one column with the compact brand header. The PIN can be revealed with an
  explicit toggle, errors render as an inline high-contrast banner (live
  region), the button keeps a 48 dp target and device language/appearance pick
  from the corner before signing in. The debug banner is gone.
- Capacity reservations: summary metrics (active / expiring soon), a filter
  card with plate search and "expiring only", cards that show the hold window,
  category chip, notes and warning countdown, and an empty state that explains
  holds and creates the first one.
- Monthly passes: summary metrics (active passes and pending payments with the
  amount due), filter card with plate search and "active only", section
  headers for pending payments and registered passes, a typed empty state and
  no-match state with a clear action.
- Categories and tariffs empty states explain what is missing and offer the
  matching create action.
**UI/UX pass across every module**

- Shared UI kit (`core/widgets`): `SectionHeader`, `MetricCard`, `FilterBar`,
  `SkeletonCardList`/`SkeletonTable`, and upgraded `EmptyState`/`ErrorState`
  with a title, tonal icon, explicit call to action and localized retry.
  Documented in [`docs/ui-kit.md`](docs/ui-kit.md).
- Notifications: grouped by day (today / yesterday / earlier), unread filter
  with a count, tonal type icons, unread emphasis and an empty state that leads
  to the records page.
- Audit: filter card with the entry count and date chip, localized action chips
  (create/update/delete), row dialog that compares **before → after** per field
  and a clear-filters empty state.
- Users: search by name or username, role segments, initials avatars, role
  chips and a first-user CTA.
- Records: search and range filters inside one card with the result summary,
  exports behind a single menu and a title on the empty state.
- Home: quick actions as 48 dp tiles, section headers with hints for quick
  actions and the live summary.
- Vehicle history: visit/spend as `MetricCard`s and a section header for the
  movement list. Shifts and spots use card skeletons and empty states; settings
  reuses the shared section header.
- Currency labels stop hardcoding COP: "Valor", "Descuento" and "Base inicial"
  follow the site currency (the symbol comes from `Money`).

**Multi-currency (COP/USD) and Spanish/English**

- `parking_settings.currency` (`0068`, `COP` default, `USD` allowed) is exposed
  by `public_lot_profile`. Amounts remain integers in the currency minor unit
  (COP pesos, USD cents); `core/money` formats `$5.000` / `US$50.00`, parses
  operator input with either separator and writes CSV in major units. The
  currency is ambient (`Money.configure` from `BrandingCubit`), so screens,
  PDFs, printed receipts, fare breakdowns, cash counting and the shift drawer
  adapt with no per-widget plumbing. Ajustes has a currency selector and
  money inputs accept decimals for USD.
- The interface is translatable between Spanish and English with a device-level
  preference (`LocaleCubit`, Hive `preferences/locale`): system, Español or
  English from the translate button in the home app bar. Tests without the
  cubit keep the Spanish `defaultLocale`.

**Operator UI/UX (space board and settlement)**

- Home **space board** (`slot_board()` + `SlotBoardCard`): virtual capacity
  cells for cars+pickups and motorcycles with four semantic states (free,
  occupied with plate and elapsed time, reserved, and the skeleton/empty/error
  states), per-group headers (`free / capacity`), filter chips with icons
  (all/cars/motorcycles/holds) and 44×48 dp targets. Tapping a vehicle opens a
  sheet with its exact entry time, a one-second clock, pass/keys/photo chips,
  the server fare breakdown and a direct exit.
- Settlement dialog explains the charge: elapsed time, billed day hours ×
  hourly rate, night hours × nightly rate, daily cap, total, and the payment
  methods with icons. A monthly pass shows as covered; a failed preview still
  lets the operator charge.
- `fare_breakdown` (`0053`) is the single source of truth for money:
  `calculate_fare` is a thin wrapper over it and `check_out_preview` returns the
  breakdown, so the explanation can never drift from the charge.
- The occupancy KPI adds a radial gauge (percentage as text) next to the
  existing bar.
- Check-in suggests known plates after two typed characters (tap to fill and
  look it up); it is optional and never blocks the manual field.
- Cash closing is safer: the close/adjust dialogs show the **expected cash**
  and a live **difference** while typing, and a **denomination counter**
  (100.000 → 100 COP notes/coins) totals the drawer and fills the counted
  amount, so the arqueo is arithmetic the app does, not the operator.
- On-screen alphanumeric keypad (`PlateKeypad`) for touch cabins: opens from the
  plate field and the check-out search, 52 dp keys, backspace/clear, respects
  the plate length limit and feeds the normal lookup/debounce.
- Admins can **release a hold from the board**: tapping a reserved cell opens
  its sheet with "Cancelar reserva" (confirmation, snack, board reload); the
  reservation id is resolved from the active list by plate + expiry, so the
  board payload stays small. Operators do not see the action.
- **Physical parking map (drag & drop).** Admins lay out the site once in
  `/spots`: add bays, drag them on a grid, rename them, take them out of
  service or delete them (`parking_spots`, audited). Each bay has a code,
  group (cars / motorcycles / heavy) and grid position. Check-in then offers
  that group's free bays (default "Automatic" = first free, top-left first) and
  `check_in` assigns the bay; the home board paints the real map with the car
  in its bay and the fare sheet shows the spot. With a map, the group's capacity
  **is** its active bays (`0058`), out-of-service bays are never offered, and
  holds obey the same limit. Deleting a bay clears the reference on old
  sessions instead of blocking (`0059`). The entry receipt/snackbar names the
  assigned spot.
- **Print no longer hides behind the receipt.** "Imprimir" closes the receipt
  dialog first (post-frame) and then opens the print sheet, so the
  printer/PDF choice is always on top.
- **Mobile navigation: 5 tabs + drawer.** The phone layout keeps four main
  destinations (Inicio, Entrada, Salida, Registros) and a fifth **Menú** tab
  that opens a drawer with the rest (notifications, contact, management
  sections for admins) plus the site/user header and sign-out; the wide layout
  keeps the sidebar.
- **Cash received and change are stored.** The amount handed over and the
  change go into `parking_sessions.cash_received/cash_change` (`0067`,
  `check_out(p_cash_received)`); short cash is refused server-side and the
  receipt (screen/PDF/thermal) prints "Recibido" and "Cambio".
- **Cash change and card type at settlement.** Cash payments ask "how much did
  the customer hand over?" and show the change (or shortfall) live, blocking the
  charge when the cash does not cover the total. Card payments ask **debit or
  credit** and store it in `parking_sessions.card_type` (`0066`,
  `check_out(p_card_type)`, required for cards); receipts and the PDF/thermal
  print "Tarjeta débito/crédito".
- **Editable legal policy / service contract.** Ajustes gains a "Policies and
  contract" section with the full text (seeded from a server default template
  with `{{parking}}`, `{{address}}`, `{{schedule}}`, `{{phone}}` tags), a
  "Restore template" action (`reset_legal_policy`) and a preview. The public
  evidence page links to `/policies?lot=..`, where the customer reads the
  contract with the tags filled in — no login, identity/contact/policy only
  (`public_lot_profile`, `0065`).
- **Shareable evidence with the ticket.** Every receipt now prints two codes:
  the **check-out QR** (the plate) is bigger (176 px on screen / 140 in the PDF)
  and, below it, a **smaller evidence QR** linking to the public page
  `/evidence?session=..`, where the vehicle's photos and videos are shown after
  the customer types the **plate as the access key** (no login; the link alone
  is not enough). The page fetches
  short-lived signed URLs from the new `public-evidence` Edge Function, which
  verifies the session + plate and never exposes other sessions. Requires
  `--dart-define=APP_URL=<public app URL>` so the printed link is reachable.
  `tool/evidence-web.nginx.conf` serves the public build with the SPA fallback
  needed by the path URL strategy (dev host runs on port 8080).
- **Optional walk-around video at check-in.** The operator can record a short
  clip (max 60 s, 50 MB) of the vehicle's condition; it is optional like the
  photos, uploads to the same evidence bucket and is stored as
  `evidence_photos.kind = 'video'` (`0064`) so retention/archive and the
  membership read policy keep working. The check-in response and the space
  sheet show the video count, and the queued (offline) check-in persists the
  clip until it replays.
- **Records filters and exports.** The log filters by business-date range
  (All / Today / 7 days / 30 days or a custom picker, `0063`) next to the plate,
  shows the matching total and can export the **whole filtered set**: CSV to the
  clipboard (raw numbers, RFC 4180 quoting) or a PDF with a summary and one row
  per session, shared through the OS sheet.
- **Records section.** New `/records` page (nav "Registros" and the home
  shortcut) lists the site's latest sessions with plate, entry → exit,
  duration, charge or "Dentro"; the plate filter is server-side and debounced,
  the header shows the matching total (how many times that vehicle entered),
  paging loads more, and tapping a row opens that vehicle's full history
  (visits, spend, notes, WhatsApp). Backed by `session_records()` (`0062`),
  lot-scoped and tested for filter/paging/isolation.
- **Settings form reorganized.** The page is split into Identity / Spots and
  map / Evidence / Messaging sections with even spacing between fields (the
  helper lines no longer collide with the next outline) and two-line helpers.
  When a site already has a map, the per-group "out of service" counters are
  replaced by a note with the bays under maintenance and a link to the map,
  because out-of-service is then a per-bay state.
- **Occupied bays are blue.** Filled bays use the primary (blue) tint while
  free bays stay green and maintenance stays grey/hatched, so a car inside is
  obvious at a glance on the dashboard, the check-in picker and the virtual
  board (holds keep amber). Covered by a color regression test.
- **Check-in picks the bay on the map.** The "Espacio" section draws the
  configured layout (same cells as the dashboard): free bays are tappable,
  occupied ones show their plate, maintenance is striped and holes keep the
  shape; "Automatic" stays the default (server takes the first free bay).
- **Board map alignment.** Dashboard bays now scale uniformly to fit the card
  (`SpotCellView` 56–72 px, same gap as the editor), empty holes are exactly the
  same size as filled bays, and the "N vehicles with no spot" note has a
  singular form.
- **The configured capacity is the number of bays.** The map editor shows
  `drawn / configured` per group (`0060`): a group cannot take more bays than
  its capacity and cannot drop below it (lower the capacity in Ajustes first);
  the add dialog disables full groups and the server enforces the same rule
  (`SpotCapacityReachedError` / `SpotCapacityRequiredError`). `capacity_snapshot`
  exposes the configured target next to the drawn count (`0061`), so the editor
  keeps the right goal after the first bays exist. The editor and the
  dashboard board share one `SpotCellView` (72 px bays, 6 px gaps, same colors,
  stripes and icons), so the dashboard draws an exact copy of the configured
  layout.
- **Live activity notifications.** Every check-in/check-out now notifies the
  whole site (all active members, not only admins) with the actor's name, the
  plate and the charge on exits (`0056`), so the admin desk sees the operator's
  phone activity and the phone sees the web's, through Supabase Realtime. The
  snackbar is localized from the payload, the inbox keeps the row, and the
  acting device ignores the echo of its own write (`LocalActivity`).
- **Realtime refresh.** Receiving an activity alert now refetches the data as
  well as showing the snackbar: the shell reloads the dashboard and shift
  summaries, the check-out list reloads (preserving the search) and the check-in
  open sessions/holds reload, so the other device never shows a stale counter.
- **Realtime fix.** The notifications policy used `current_lot_id()`, which
  Realtime evaluates without the `x-lot-id` header: the subscription died with
  `LotRequiredError` and live snackbars never arrived. It now uses the
  security-definer `can_read_lot()` membership check (`0057`), verified with a
  real WebSocket subscription (join → check-in → `postgres_changes` payload).
- **Out-of-service spaces.** Admins can take car or motorcycle spots out of the
  usable pool in Ajustes (`car_out_of_service`, `moto_out_of_service`). They
  stay in the configured capacity, are painted as striped "Mantenimiento" cells
  on the board, and are never offered: the capacity guard, reservations, the
  dashboard snapshot and the check-in remaining-spaces labels all use
  `usable_capacity()` (`capacity - out_of_service`, `0` capacity = no limit).

**Core operations**

- Offline-first check-in/check-out with a Hive outbox, idempotency keys
  (`client_ref` generated before the first attempt), client-captured times with
  server-side clock-skew validation, and an optimistic pending session.
- Time-based billing in SQL: hourly with per-day ceiling, daily cap, night
  window that replaces the day tariff, monthly pass → 0, per-day boundaries in
  the site's `business_timezone`.
- Cash shifts ("arqueo"): opening float, withdrawals/deposits, expected vs
  counted cash, difference, close notifications, and admin-only corrections
  with a mandatory reason stored in `shift_adjustments`.
- Payments: payment method required at check-out, admin discounts with a
  mandatory reason and audit trail, lost ticket charging the full daily tariff
  with a reason, monthly-pass charges collected into a shift.
- Capacity per category with reservations: active holds consume capacity, a
  check-in consumes the plate's hold, and expired holds are released.
- Vehicle registry with notes, admin-only blacklist that blocks check-in, and a
  plate history showing every visit with its site, amount, discount, ticket and
  loss-of-ticket flag.
- Evidence photos at check-in (Storage) with per-site retention and a scheduled
  `evidence-archive` function that deletes objects and rows past the window.

**Multi-site**

- `parking_lots` + per-site membership/roles; every site-owned table carries
  `lot_id`; capacity, tariffs, shifts, passes, reservations, settings, reports
  and notifications are site-scoped.
- Mandatory `x-lot-id` header validated against membership
  (`LotRequiredError` otherwise); offline replays carry the captured lot through
  `resolve_lot()`.
- Per-site branding (logo object `branding/logo_<lotId>`), per-site evidence and
  settings, lot switcher in the shell, admin `/lots` page with member roles.
- Consolidated admin report with a per-site comparison (revenue, charged exits,
  average ticket, share of total) and a PDF/CSV-friendly export.

**Customer communication**

- Optional customer phone per vehicle; receipts and monthly-pass reminders can
  be shared as prefilled `wa.me` links (no provider, no cost).
- "Vehicle ready for pickup" notice for open sessions.
- Automated WhatsApp mode per site: messages are queued in `whatsapp_messages`
  and a service-role `whatsapp-dispatch` function sends approved Meta templates
  (receipt, pass expiry, ready) with retries; delivery metrics appear in the
  revenue report and the queue in `/diagnostics`.

**Notifications**

- In-app inbox + bell over Realtime (no configuration), with deep links by type
  (shift, monthly passes, vehicle history by plate).
- Background push: FCM for Android (`push-dispatch`) and Web Push with VAPID
  (`web/push-sw.js` + subscriptions table); both optional and safe no-ops when
  unconfigured.

**Administration**

- Admin users page with create, role/active changes, PIN reset and delete;
  `admin-users` Edge Function enforces last-admin and self-delete protections.
- Audit log for reference data (categories, tariffs, vehicles, passes,
  settings, lots, memberships) and user actions, with actor, lot and changed
  columns; `/audit` filters by table/actor/date and exports PDF or CSV.
- Per-site settings (identity, contacts, business timezone, overstay hours, lost
  ticket fee, evidence retention, automated WhatsApp).
- `/diagnostics` panel: migrations, sessions/shifts with age warnings, pending
  payments, reservations, notification and WhatsApp backlogs, storage usage and
  client error reports (stack + context).

**Operations**

- Nightly backup (`backup.sh`) of database + Storage, guarded restore
  (`restore.sh`) and a **safe restore drill** (`restore-drill.sh`) that restores
  into a scratch database and compares schema, RPCs, RLS policies, grants, row
  counts and the storage archive.
- Retention jobs: expired reservations, stale notifications, client error
  reports, audit log and WhatsApp queue; idempotency purge.
- Healthcheck (`healthcheck.sh`) with exit code + optional webhook alert, and a
  diagnostics snapshot (`diagnostics.sh`/`diagnostics.sql`).
- Secret hygiene script (`check-secrets.sh`), host-side PIN rotation
  (`rotate-pin.sh`) and a rotation/leak runbook.
- Structured JSON logs in every Edge Function (one line per request).

### Changed

**UI/UX**

- Check-out and check-in lists show how long each car has been parked, and
  check-out flags stays over 24 h.
- Monthly passes show a status chip (active/upcoming/expired) and sort active
  passes first, then upcoming, then expired.
- Creating a vehicle confirms it with a snack that offers to register its
  check-in straight away.
- Creating, deleting or collecting a monthly pass and creating or cancelling a
  reservation confirm with a SnackBar and a screen-reader announcement.
- New reservations offer quick holds (+2 h, +4 h, end of day) next to the
  date picker.
- Monthly passes that are expired or end within a week show a "Renew 30 days"
  action (extends from the day after the end, or from today when expired,
  keeping the amount) with a confirmation.
- On wide screens the home no longer repeats the management shortcuts (the
  sidebar lists them) and clips the sidebar while it animates open/closed.
- The web shell uses a **collapsible side navigation** (persisted per device)
  with the brand, Operación/Gestión groups, and a footer carrying the active
  site and the signed-in user; page content widens to 1080 px on desktop.
- The multi-site indicator is now a compact chip in the home content (it used
  to be a full-width strip above the app bar that read like a notification).
- The home app bar picks the device appearance (system / light / dark); the
  choice is stored locally and survives restarts.
- The ticket QR keeps its full matrix and quiet zone (the modules were clipped
  by the padded canvas) and is now verified by rendering + decoding it in a
  widget test.
- The home occupancy figure counts the **configured spaces** (cars+pickups and
  motos; trucks/buses excluded), the check-in dropdown disables a category only
  when its whole group is full, and on wide screens the cars-inside list moves
  to a **side panel**.
- The home dashboard is reorganized: the **Entrada/Salida actions come first**,
  the KPIs (occupancy, capacity, today, shift) sit in a two-column responsive
  grid under a "Summary" label, cards use tinted icon headers, and the
  management shortcuts are a two-column tile grid. A capacity card (below)
  shows the configured spaces.
- The home is a real dashboard: a **capacity card** (cars/pickups, motorcycles
  and keys: inside vs. limit, with bars) and a **cars-inside list** with plates,
  elapsed time, pass/photo hints and "See all" to check-out.
- The home capacity card summarizes active holds (and how many expire within
  two hours) with a shortcut to the reservations screen for admins; the
  check-in screen shows the plate's active hold and can cancel it when the
  customer does not arrive.
- The home capacity card shows spots on hold (active reservations) next to
  the occupied ones (`0050`).
- Active reservations consume the configured **group spaces** too: a site
  cannot promise more spots than it has and a walk-in cannot take a promised
  one (`0049`).
- Ajustes gains the site's **space configuration**: spaces for cars and
  pickups (shared), spaces for motorcycles and the maximum number of cars that
  may leave their keys (`0` = no limit). The check-in form has a "Leaves the
  keys" switch, the list shows it, and the server enforces the three limits
  (`ParkingFullError`/`KeysFullError`); trucks and buses are not limited.
- The check-in category dropdown shows the **remaining spaces** of the group
  (held spots included) next to each option, so the operator knows before
  choosing.
- Check-out shows a **keys** chip on cars that left them, and
  `evidence-archive.sh` honors the gateway port from `.env`.
- The check-in "vehicles inside" widget is an **accordion** with the count:
  each car offers its receipt (QR + print) and **Mark exit**, which jumps to
  check-out with that plate.
- Admins can see the cars still inside from check-out and **reprint their
  entry ticket** (QR + Imprimir) from each row, for a lost or damaged ticket.
  The row subtitle wraps its chips and shortens the elapsed time on phones.
- Check-in shows the **ticket with its QR as soon as the entry is registered**
  (with Imprimir right there), on screen, in the PDF and on thermal printers. At the exit, the app's
  camera scan opens that session's payment dialog; a USB QR reader can type the
  plate into the search field and Enter opens it too. On phones the scanner is
  a **live camera preview** (`mobile_scanner`) that detects the QR
  automatically and closes itself; web keeps the photo/USB-reader path. The
  photo decoder is pure Dart (`zxing2`) and works offline.
- The shell's WhatsApp shortcut is now a **QR scan shortcut** that reads a
  receipt and opens its check-out (with `/check-out?scan=PLATE`).
- Check-out shows the shared empty state (no cars inside, or no plate match)
  and a "Clear search" action on a miss.
- Leaving the settings form with unsaved edits asks before discarding them.
- Empty users/vehicles/monthly-pass lists offer their first action (add) right
  in the empty state instead of only the FAB.
- The users list filters by role (All / Admin / Operator) and monthly passes
  have a plate search (pending payments included), both with a no-match state.
- Empty lists (reservations, sites, audit) use the same friendly empty-state
  component instead of bare text. Reservations sort by expiry and flag holds
  that lapse within two hours with a "expires in …" warning chip, and each
  reservation opens check-in with its plate already prefilled.
- The home "today" card shows a quiet-day message instead of a row of zeros
  before the first movement, with a cross-fade between both states.
- Vehicles list has a server-side plate search (debounced), a no-match state
  and keeps the term when refreshing.
- Reports have quick ranges (Today / 7 days / 30 days) next to the calendar
  picker, and picking a custom range clears the preset.
- Shared `SearchField` (vehicles and check-out): type-to-search autofocus on
  web/desktop, a clear button and `Esc` to reset. `Ctrl/Cmd+K` focuses the
  search of the current screen from anywhere in the app.
- Screen readers announce successful check-ins and check-outs.
- Check-in warns inline when the plate is already inside, before submitting.
- Check-in remembers the last plate and offers a one-tap "repeat entry" chip;
  plate fields normalize while typing through the shared `PlateInputField`
  (uppercase, no blanks) and cap at the 20-char column width.
- The occupancy bar honours `reduce motion` (fills instantly), and the same bar
  plus the monthly-pass status chip animate their changes, while
  vehicle/reservation rows fade-slide in once when a list appears (disabled
  under `reduce motion`).
- Closing a shift whose counted cash differs from the expected amount asks for
  confirmation, showing the difference.
- Shift cash actions (open, close, movement, correction) confirm with a
  SnackBar and a screen-reader announcement instead of happening silently.
- An open session in the vehicle history offers "Cobrar en caja", opening
  check-out filtered by that plate.
- The check-out receipt offers "Nuevo cobro", which clears the search and
  refocuses it so the next car can be charged without leaving the screen.
- The check-out list flags cars covered by an active monthly pass, so the
  operator knows the stay is free before opening the payment dialog (`0046`).
- Check-out remembers the last payment method and preselects it (a pass only
  preselects "monthly pass" when the session is actually covered).
- Reports compare the selected period with the previous, equally long one:
  a signed **% variation** plus the previous total, hidden when that window
  cannot be loaded. The exported PDF carries the same comparison, and the CSV
  button copies a spreadsheet-ready dump (raw numbers, one row per figure).
- Check-out shows the **estimated fare before charging**
  (`rpc/check_out_preview`) and "monthly pass: no charge" when a pass covers the
  stay; a failed preview still opens the payment dialog.

- The app selects the active lot **before** exposing an authenticated session,
  so the first request already carries `x-lot-id`.
- Printed receipts (PDF and thermal) follow the app language via
  `ReceiptLabels`; ticket numbers include the site code (`TCK-<LOT>-000123`).
- List screens use skeleton loaders that honour the reduce-motion setting.
- Reports accept an "all sites" view for platform admins.
- Check-in with evidence photos works again on a real device: uploads are
  insert-only (the evidence SELECT policy only exposes a photo after
  `check_in` records it), and a replayed upload accepts the existing object.
- New app mark: dark asphalt badge, chunky safety-yellow "P" and a hazard
  curb; it ships as the Android launcher icon, the web/PWA icons and favicon,
  and the login header fallback until a site uploads its own logo. Regenerate
  with `python3 tool/generate_branding.py` (Pillow).
- Hive initializes before the Supabase boot, so a **fresh Android install**
  can open its boxes (the cached-session cleanup used to throw `HiveError` on
  first launch; web was unaffected).
- `restore.sh` now runs `pg_restore` as `supabase_admin` (restoring as
  `postgres` silently lost every grant).

### Fixed

- Per-site branding no longer overwrites another site's logo, and branding
  reloads when the active site changes.
- Evidence downloads work after the mandatory-lot-header change: Storage cannot
  forward `x-lot-id`, so the bucket policy uses a membership-based helper.
- Capacity holds are released when they expire instead of blocking a lot
  forever.
- The overstay cron evaluates every site with its own threshold instead of a
  single implicit lot.
- Zoned date boundaries are consistent across billing, reports and KPIs.
- Settings, notifications, categories, tariffs and passes caches are keyed per
  site, so offline devices never mix two sites.

### Security

- Row Level Security on every table; writes go through `security definer` RPCs
  that derive the actor from `auth.uid()`.
- GoTrue-only auth: 6-digit PIN minimum enforced server-side, signup disabled,
  `/token` rate-limited by client header.
- Evidence objects readable only through a session of a lot the user belongs to.
- Service-role key confined to Edge Functions/cron; never in the client.
- Audit trail never stores secrets (`pin_hash` is stripped).
- Secret rotation and leak-response runbooks, plus a hygiene checker in CI docs.

### Operations & CI

- CI runs Flutter analyze/tests/web build, compose validation, the SQL/RLS
  regression suite, and a real-stack job (backup + restore drill + API e2e +
  Flutter↔Supabase e2e) on `main`, `feature/**` and PRs.

### Documentation

- `docs/`: environment guide (EN/ES), quickstart, local and cloud setup,
  architecture and infrastructure diagrams (Mermaid), database ER/catalog,
  restore and secrets runbooks, and a durable agent memory.
- OpenSpec capability specs with the multi-site change archived.

### Tests

- 785 Flutter tests (unit/widget/cubit/router/a11y) across 109 files, plus one
  integration test that runs only against a live stack.
- SQL/RLS/RPC regressions covering capacity, shifts, discounts, passes,
  reservations, multi-site isolation, audit, diagnostics and retention.
- `flutter analyze` reports **zero errors, zero warnings** and only SDK
  `deprecated_member_use` infos from the pinned beta channel.

### Cloud helpers

- `supabase/apply-cloud.sh` applies every migration to a hosted project and
  `supabase/create-cloud-operator.sh` creates a kiosk user through the Admin
  API with a secret key; `docs/setup-cloud.md` documents the hosted checklist
  (empty project → `PGRST205`/`invalid_credentials`).

## Database migrations

Migrations are append-only and applied in filename order by `supabase-migrate`.

| Range | Area |
|---|---|
| `0001`–`0004` | Core schema, auth trigger/RLS, storage buckets, reference seed |
| `0005`–`0007` | Business RPCs, public branding, RLS tightening, domain constraints |
| `0008`–`0010` | Notifications, payments/overstay, vehicle history |
| `0011`–`0013` | Capacity + discounts + shifts, shift RPCs, pass renewal |
| `0014`–`0018` | Idempotency purge, discount audit, pass charges, backfill, shift adjustments |
| `0019`–`0022` | Lost ticket, vehicle notes/blacklist, reservations, Web Push |
| `0023`–`0026` | Multi-site schema, lot-scoped RLS/RPCs, offline replay, member listing |
| `0027`–`0032` | Per-lot branding, retention, shift filters, header contract |
| `0033`–`0038` | Evidence retention, storage membership, diagnostics, audit export, report comparison, home KPIs |
| `0039`–`0044` | Site comparison fields, ticket reprint, customer phone, WhatsApp queue/report |
| `0045`–`0059` | Check-out preview, pass flag, capacity groups, reservations consuming group capacity, reserved counts, hold counters, space board, fare breakdown, out-of-service spaces, live activity notifications, physical spot map and its editor |

## Verification snapshot

Captured on 2026-10-24 against the local self-hosted stack:

| Check | Result |
|---|---|
| `flutter test` | 785 passed (+1 live-stack integration skipped) |
| `flutter analyze` | 0 errors, 0 warnings (only SDK deprecation infos) |
| `flutter build web --release` | OK |
| `supabase/tests/run.sh` | Passed (migrations + RPC/RLS regressions) |
| `supabase/tests/e2e.sh` | Passed (login → check-in → check-out → report → history) |
| Flutter↔Supabase integration test | Passed |
| `healthcheck.sh` | No failures |
| `restore-drill.sh` | Passed (backup restorable) |

## Notes

- Targets Android and Web (no iOS target in the repo).
- Receipts are internal only; there is no electronic invoicing.
- Currency is COP (no decimals); UI is Spanish by default with English
  translations at parity.
- FCM/VAPID/Meta credentials are operator-provided; the repo ships safe no-op
  behavior without them.
