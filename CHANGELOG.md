# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project aims at [Semantic Versioning](https://semver.org) once it
publishes its first release. **The project is pre-1.0: there are no tagged
releases yet; everything below is unreleased work on `feature/supabase`.**

## [Unreleased] — 2026-10

### Added

**UI/UX pass across every module**

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
