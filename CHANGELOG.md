# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project aims at [Semantic Versioning](https://semver.org) once it
publishes its first release. **The project is pre-1.0: there are no tagged
releases yet; everything below is unreleased work on `feature/supabase`.**

## [Unreleased] — 2026-10

### Added

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
- Check-in remembers the last plate and offers a one-tap "repeat entry" chip;
  plate fields normalize while typing through the shared `PlateInputField`
  (uppercase, no blanks) and cap at the 20-char column width.
- The occupancy bar and the monthly-pass status chip animate their changes, and
  vehicle/reservation rows fade-slide in once when a list appears (disabled
  under `reduce motion`).
- Shift cash actions (open, close, movement, correction) confirm with a
  SnackBar and a screen-reader announcement instead of happening silently.
- The check-out receipt offers "Nuevo cobro", which clears the search and
  refocuses it so the next car can be charged without leaving the screen.
- Check-out remembers the last payment method and preselects it (a pass only
  preselects "monthly pass" when the session is actually covered).
- Reports compare the selected period with the previous, equally long one:
  a signed **% variation** plus the previous total, hidden when that window
  cannot be loaded. The exported PDF carries the same comparison.
- Check-out shows the **estimated fare before charging**
  (`rpc/check_out_preview`) and "monthly pass: no charge" when a pass covers the
  stay; a failed preview still opens the payment dialog.

- The app selects the active lot **before** exposing an authenticated session,
  so the first request already carries `x-lot-id`.
- Printed receipts (PDF and thermal) follow the app language via
  `ReceiptLabels`; ticket numbers include the site code (`TCK-<LOT>-000123`).
- List screens use skeleton loaders that honour the reduce-motion setting.
- Reports accept an "all sites" view for platform admins.
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

- 591 Flutter tests (unit/widget/cubit/router/a11y) across 109 files, plus one
  integration test that runs only against a live stack.
- SQL/RLS/RPC regressions covering capacity, shifts, discounts, passes,
  reservations, multi-site isolation, audit, diagnostics and retention.
- `flutter analyze` reports **zero errors, zero warnings** and only SDK
  `deprecated_member_use` infos from the pinned beta channel.

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

## Verification snapshot

Captured on 2026-10-24 against the local self-hosted stack:

| Check | Result |
|---|---|
| `flutter test` | 591 passed (+1 live-stack integration skipped) |
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
