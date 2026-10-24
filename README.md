# Parking Management

Offline-first parking management system: vehicle check-in/check-out, time-based
billing (hourly/daily/nightly rates, per-day caps), vehicle categories, monthly
passes, evidence photos, license-plate OCR scanning, and admin revenue/occupancy
reports.

- `supabase/` — self-hosted Supabase stack + SQL schema, RPCs, RLS, Storage
  buckets and the admin-users Edge Function (source of truth)
- `lib/` — Flutter app (Android + Web), Hive-backed offline cache + sync outbox
- `openspec/` — specs and change history (spec-driven development); see
  `PROGRESS.md` for the capability changelog

There is no application server: the client talks to Supabase Auth, PostgREST and
Storage directly, and business rules live in PostgreSQL functions.

## Documentation

| Guide | Contents |
|---|---|
| [`docs/setup-local.md`](docs/setup-local.md) | Full local setup from zero: secrets, stack, admin user, Flutter, tests, troubleshooting. |
| [`docs/setup-cloud.md`](docs/setup-cloud.md) | Production on a VM: TLS proxy, hardening, backups, cron, push credentials, Android release, upgrades. |
| [`docs/architecture.md`](docs/architecture.md) | Components, Flutter layers and the check-in/billing/shift/notification/multi-site flows. |
| [`docs/infrastructure.md`](docs/infrastructure.md) | Services, ports, volumes, env vars, operations, scaling and CI. |
| [`docs/database.md`](docs/database.md) | ER diagram, tables, RPC catalog, RLS model and migration rules. |
| [`docs/agent-memory.md`](docs/agent-memory.md) | Current state, invariants and gotchas for the next session. |

## Architecture

```
Flutter (hexagonal, per feature)
  domain -> application -> infrastructure -> presentation
                                |
                 Supabase client (JWT, PostgREST, Storage, Functions)
                                |
        Envoy gateway :8000 -> GoTrue / PostgREST / Storage / Realtime
                                |
                      PostgreSQL 17 (public schema + RLS)
```

- **Auth**: GoTrue. The kiosk asks for username + 6-digit PIN; the client maps it
  to `<username>@parking.local` and the PIN as the password.
- **Reads/writes**: PostgREST with RLS. `anon` has no table grants.
- **Business logic**: `public.check_in`, `public.check_out`,
  `public.calculate_fare`, `public.report_revenue`, `public.report_occupancy`,
  `public.set_branding_logo` (security definer, operator derived from
  `auth.uid()`).
- **Users**: `admin-users` Edge Function (service-role stays server-side).
- **Photos/logo**: Supabase Storage (`evidence` private, `branding` public).
- **Offline**: Hive cache + outbox; replays the same RPCs and `client_ref`
  idempotency keys.

## Quickstart

```bash
cp .env.example .env
sh supabase/generate-env.sh     # generates DB/JWT/dashboard/API keys
docker compose up -d --build    # pulls Supabase, applies migrations

sh supabase/create-operator.sh admin 123456 admin
```

| What | Where |
|---|---|
| Supabase API gateway | http://localhost:8000 |
| Studio | http://localhost:8000 (basic auth `DASHBOARD_*`) |
| Auth | http://localhost:8000/auth/v1 |
| REST | http://localhost:8000/rest/v1 |
| Storage | http://localhost:8000/storage/v1 |
| Postgres (Supavisor) | `localhost:5432`, database `parking` |

Migrations in `supabase/migrations/` are applied once by the
`supabase-migrate` one-shot service and tracked in `public.schema_migrations`.
See [`docs/setup-local.md`](docs/setup-local.md) for the full walkthrough
(requirements, emulator host, tests, troubleshooting) and
[`docs/infrastructure.md`](docs/infrastructure.md) for operations, resets and
security notes.

## Flutter

Requires the Flutter SDK (beta channel, see CI) and the running stack.

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY from .env>
```

- Android emulator: use `http://10.0.2.2:8000` (debug builds allow cleartext).
- Release builds must point at an HTTPS gateway; Android blocks cleartext by
  default, so terminate TLS in front of Envoy (Caddy/nginx) for production.
- Web: run `flutter run -d chrome --web-port 5000`; the gateway allows the
  origins configured by the stack (adjust `supabase/volumes/api/envoy` if you
  restrict them).
- Tests: `flutter test`. Static analysis: `flutter analyze`.

## Operators and roles

```bash
sh supabase/create-operator.sh juan 123456 operator
sh supabase/create-operator.sh admin 123456 admin
```

The `auth.users` trigger mirrors the profile into `public.users` and copies
`app_metadata.role`. PINs must be 6 digits (GoTrue minimum). Admins manage users
from the app; creation/role/active changes go through the `admin-users` Edge
Function.

## Notifications and push

**In-app (works out of the box):** PostgreSQL triggers create rows in
`public.notifications` for admin check-in/check-out events; monthly pass
expiry alerts come from `notify_expiring_monthly_passes()` and overstay alerts
from `notify_overstays()` (default 24 h, configurable in
`parking_settings.overstay_hours`). The Flutter app
subscribes to `public.notifications` through Supabase Realtime (RLS-scoped),
shows a bell with the unread count and an inbox at `/notifications`, and shows
a banner when a new row arrives.

**Background push (FCM):** Supabase does not deliver push itself. Set
`FCM_SERVICE_ACCOUNT_JSON` in `.env` (single-line Firebase service-account
JSON), restart the `functions` service, and schedule `supabase/notifications-cron.sh`
from host cron every minute. The cron also renews monthly passes, raises
overstay alerts and purges expired idempotency keys. The `push-dispatch` Edge
Function sends pending notifications to FCM and is protected by the service-role
key.

**Flutter (Android):** register the app in Firebase
(`pro.devpaul.parking_management`) and run with:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=FCM_ENABLED=true \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

The device token is registered automatically after login. Without
`FCM_ENABLED`/Firebase options the app still gets in-app notifications.

**Browser push (VAPID):** the web build ships `web/push-sw.js`, a service
worker that renders the OS notification and deep-links on click. Subscriptions
live in `public.web_push_subscriptions` (one row per browser, owner derived
from `auth.uid()`), and `push-dispatch` delivers to them with `web-push` when
the VAPID keys are present:

1. Generate the key pair: `npx web-push generate-vapid-keys`.
2. Put `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` and `VAPID_SUBJECT` in `.env`
   and restart the `functions` service.
3. Build the web app with the same public key:
   `flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=<public key>`
4. Serve it over HTTPS (service workers require a secure origin) and enable
   **Notificaciones del navegador** from the inbox. Without the key the toggle
   stays hidden and the function skips web push.

Real Android credentials still have to come from your own Firebase project
(`FCM_SERVICE_ACCOUNT_JSON` for the server, the `FIREBASE_*` dart-defines for
the app); nothing in the repository can generate them.

## Check-out, payments and history

Check-out asks for the payment method (cash, card, transfer, monthly pass or
exempt); monthly passes override the selection and charge zero. Admins can also
apply a discount with a mandatory reason; the actor, instant and reason are
stored with the session and revenue reports show the discounted total. Receipts
(screen, thermal, PDF) include the method and discount.

The `/history` screen (also linked from Home) looks up a plate and shows its
visits, total spent, open-session flag and the latest sessions, with an offline
cache per plate. Every session is tagged with its site, and when the plate has
visited more than one site a filter narrows the timeline to one of them. A
closed session can **reprint its ticket**: the same amounts (including any
discount) and ticket number are rebuilt from history and can be printed again.
Each vehicle can also store the **customer's phone**; once set, a closed
session offers "send receipt via WhatsApp" (`wa.me` with the receipt prefilled,
no external provider) and the phone chip opens a chat with the lot. Monthly
passes of that vehicle get a "notify via WhatsApp" action with the expiry date
prefilled. Check-out searches plates **server-side** with pagination, so
a vehicle outside the first page is still found; the query shows a proper
"no plate matches" state. Discounts appear in the report with their reason,
admin and timestamp.

## Evidence retention

Each site can keep check-in photos for a limited time: `Retención de evidencias
(días)` in the settings form (`0` = keep forever, the default). The
`evidence-archive` Edge Function deletes the Storage object and its row for
sessions older than that window; it is service-role-only and meant to run
daily:

```bash
sh supabase/evidence-archive.sh            # real run
DRY_RUN=1 sh supabase/evidence-archive.sh  # report only
DAYS=30 sh supabase/evidence-archive.sh    # override every site
```

Backups (`supabase/backup.sh`) are the archive of record: take one before
shrinking a retention window.

## Diagnostics

Admins have `/diagnostics`: migrations applied, active sites, open sessions
(and those open over 24 h), shifts open over 12 h, pending pass payments,
reservations, idempotency keys, notification backlog (pending/dead push),
storage usage per bucket and the client error reports of the last 7 days with
stack and context. It reads `rpc/diagnostics_snapshot` and
`rpc/list_client_error_reports`; the host script `supabase/diagnostics.sh`
prints the same data from a shell.

## Audit log

Admins have `/audit`: every change to users, categories, tariffs, vehicles,
monthly passes, settings, sites and memberships is stored with the actor, the
lot, the affected row and the changed columns. Money-related actions keep their
own audit (discounts, shift corrections, pass payments). Filter by table, actor
and date, open an entry to see the before/after payload, and export the current
view as PDF (share/print) or CSV (clipboard).

## Reports and shifts

The admin revenue report has an **Export PDF** action (share/print sheet) with
the same numbers shown on screen, including the per-site breakdown when the
consolidated switch is on. The consolidated view compares sites with a bar per
site: revenue, charged exits, average ticket and share of the total (sites with
no movement that day still appear, at zero). The shift screen exports a one-page reconciliation
("arqueo") from the freshly closed card and from each history entry, and the
history can be filtered by date range.

## Shifts and cash reconciliation

Home shows a live shift card (open/closed, expected cash, check-outs) and the
check-out screen warns when no shift is open, linking to the cash screen.
Operators open a shift with an opening float, record cash withdrawals/deposits,
and close it by counting the drawer. The close screen shows expected cash, the
counted amount and the difference; check-outs attach to the shift open at the
exit time (including offline replays). Admins see recent shifts and receive a
close notification.

## Multiple parking sites

One installation can run several parking lots. `parking_lots` holds the sites
and `lot_members` the role each user has **per site** (an operator can work at
two locations with one account). Categories, tariffs, sessions, shifts, monthly
passes, pass payments, reservations, settings and notifications carry a
`lot_id`; vehicles stay a global registry keyed by plate, and the active lot's
category is applied at check-in.

Evidence photos are private: reads are limited to sessions of the active lot,
so a leaked object path is useless outside its site.

The active lot travels as the **mandatory** `x-lot-id` header, which the app
sets from `LotContext` (persisted locally) before exposing the session.
`current_lot_id()` validates the caller's membership on every lot-scoped
request; a missing or forged header fails with `LotRequiredError`. Scheduled
jobs and Studio work directly on the database and do not use that helper, so
they keep working without a header.

- Branding (name, address, logo) is per site: the logo is stored as
  `branding/logo_<lotId>` and `set_branding_logo` only touches the active lot.
- Admins create sites at `/lots` (platform admin), enable/disable them and
  manage their members (role per site). When creating a user, the admin can pick
  the site; the `admin-users` Edge Function writes the membership.
- The reports screen has a **Todas las sedes** switch for platform admins
  (`report_revenue_all`), which adds a per-site breakdown on top of the active
  lot's report.
- Users with more than one membership get a lot bar under the app chrome to
  switch sites; switching refreshes the dashboard and the shift card.
- Reports and occupancy are per lot; the consolidated switch keeps the same
  screen and adds the per-site breakdown.
- Queued offline check-ins/check-outs capture the lot where the operator acted
  and replay into that same site.

## Dashboard

Home shows current occupancy plus today's numbers for the active site
(`rpc/dashboard_today`): revenue, cash collected, monthly-pass collections,
entries and exits. Counters reset at local midnight using the site's
`business_timezone`; a slow summary never blocks the occupancy card.

## Capacity and reservations

Each category has an optional capacity (0 = unlimited). The dashboard shows
used/total vehicles, a progress bar and the names of full categories; a
check-in into a full category is rejected with a localized error, enforced in
the database under a per-category lock. The check-in form loads a fresh
occupancy snapshot and disables full categories before submitting.

Reservations (`/reservations`, admins) hold a slot for a plate until it checks
in, the hold is cancelled or it expires. Active holds count against the
category capacity, and a check-in converts the plate's own hold into an
occupied slot instead of being rejected.

## Lost tickets, notes and blacklist

Check-out offers a **ticket perdido** option: it ignores the monthly pass and
charges the full daily tariff (or `parking_settings.lost_ticket_fee` when set),
requires a reason, and stores both on the session so the shift report and the
vehicle history can explain the charge.

Vehicle history also shows free-text notes and an admin-only blacklist. An
operator can annotate incidents; only an admin can block or unblock a plate,
and a blocked vehicle is refused at check-in with a localized message.

## Monthly pass auto-renewal

A pass can be marked auto-renew; the notification cron creates a linked new
pass for the same duration and amount when it expires and notifies admins.
Manual passes keep the three-day expiry reminder.

## Data retention

These functions are safe to call repeatedly:

- `expire_reservations(24)` closes holds that were never used, freeing
  capacity.
- `purge_stale_notifications(90)` drops read notifications older than 90 days
  (and anything older than a year).
- `purge_expired_idempotency()` drops expired retry keys.

`supabase/notifications-cron.sh` runs all of them every minute from host cron,
which is the supported path. If your Postgres ships **pg_cron**, run
`ALTER SYSTEM SET cron.database_name = 'parking';`, restart the database,
`CREATE EXTENSION pg_cron;` and re-apply `0028_retention.sql`: it then
schedules the same jobs inside Postgres. Storage evidence files are not purged
automatically; delete them through the Storage API when you archive a period.

## Billing rules

- Tariffs per category: hourly, daily, nightly, monthly (COP).
- Night tariff is a time window that replaces the day tariff during that window.
- Fractional hours ceil once per calendar day per rate type; daily cap applies
  independently to every day touched; monthly pass → 0.
- Billing day boundaries and night windows use
  `public.parking_settings.business_timezone` (default `America/Bogota`).
- Printed receipts (PDF and 80 mm thermal) follow the app language through
  `ReceiptLabels`; thermal labels stay ASCII so they survive the CP437 code
  page.

## Backups and restore

```bash
sh supabase/backup.sh
# -> backups/<UTC timestamp>/{parking.dump,storage.tgz,manifest.txt}

RESTORE_CONFIRM=yes sh supabase/restore.sh backups/<timestamp>

# prove the backup is restorable without touching production
sh supabase/restore-drill.sh
```

The database dump is `pg_dump -Fc`; storage is the `supabase/volumes/storage`
directory. `.env` is intentionally **not** included: back it up separately so the
JWT/API keys survive a restore. Run backups from host cron, e.g. daily at 02:00,
and the drill monthly — the full procedure (including a restore on a new host)
is in [`docs/runbook-restore.md`](docs/runbook-restore.md).

## CI and SQL tests

`.github/workflows/ci.yml` runs Flutter analyze/test/web plus two Supabase jobs:
compose validation and a real `supabase/postgres` job that applies every
migration and runs `supabase/tests/rpc_test.sql` (capacity, shifts/arqueo,
discounts, auto-renewal charges and RLS isolation).

## OpenSpec workflow

New capabilities go through `openspec/changes/<name>/` before implementation;
`openspec archive` folds an approved change into `openspec/specs/`.
`PROGRESS.md` tracks the capability history and key technical decisions.

## License

MIT — see `LICENSE`.
