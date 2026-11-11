# Project overview

Executive summary of the parking management system: what it does, which modules
exist, how it is built, what is verified, and what is intentionally out of
scope. For hands-on setup see [`../QUICKSTART.md`](../QUICKSTART.md) or
[`environment-guide.en.md`](environment-guide.en.md) (English) /
[`environment-guide.md`](environment-guide.md) (español).

## 1. What it is

A **self-hosted, offline-first parking lot system** for one or several sites:
operators register entries/exits, the system prices the stay, collects payment,
reconciles the cash drawer per shift, manages monthly passes, reservations and
capacity, keeps evidence photos, and gives admins revenue/occupancy reports, an
audit trail and diagnostics. Customers can receive receipts and reminders over
WhatsApp (manual or automated).

- **Clients:** Android app and Web app from one Flutter codebase.
- **Backend:** self-hosted Supabase (PostgreSQL 17, GoTrue, PostgREST, Storage,
  Realtime, Edge Functions) in Docker. **No application server.**
- **Business logic:** SQL functions (RPCs) + RLS; Edge Functions only for admin
  user management, evidence archival, push dispatch and WhatsApp dispatch.
- **Roles:** platform admin (all sites, users, settings) and operator
  (check-in/out, cash, history); lot admins manage their own site.

## 2. Status at a glance

| Area | State | Proof |
|---|---|---|
| Check-in / check-out / billing | Complete, incl. offline | SQL tests, widget tests, live e2e |
| Shifts and cash reconciliation | Complete, incl. admin corrections | SQL + widget tests |
| Monthly passes and payments | Complete, incl. auto-renew charges | SQL + widget tests |
| Capacity and reservations | Complete | SQL + widget tests |
| Multi-site | Complete, contract enforced | SQL isolation tests, shell/router tests |
| Users and roles | Complete, last-admin guards | Edge Function verified live |
| Reports and exports | Complete (PDF, site comparison, WhatsApp metrics) | SQL + widget + PDF tests |
| Audit trail | Complete (triggers + user actions, PDF/CSV export) | SQL + widget tests |
| Notifications | In-app complete; push optional (FCM/VAPID) | Unit/widget tests, live push code path |
| Customer WhatsApp | Manual (`wa.me`) and automated queue | SQL + widget tests |
| Evidence retention | Complete (scheduled archive) | Live object deletion verified |
| Diagnostics / observability | Complete (`/diagnostics`, healthcheck, error reports) | SQL + widget tests |
| Backups / restore | Complete, with a safe drill | Drill executed against a real backup |
| Secrets / PIN operations | Complete (scripts + runbook) | PIN rotation verified live |
| E2E and CI | Complete (API + Flutter client, real stack) | CI job `supabase-e2e` |

Quality snapshot (2026-11-09, local stack): **1153 Flutter tests + 1 integration
test**, SQL/RLS suite green, web build green, analyzer with **0 errors and 0
warnings** (only SDK deprecation infos from the pinned beta channel), restore
drill green.

## 3. Module map

Each Flutter feature follows the same hexagonal layout
(`domain / application / infrastructure / presentation`); the table points at
the main data it touches.

| Module (`lib/features/…`) | Responsibility | Backing data / RPCs |
|---|---|---|
| `auth` | PIN login, session restore, logout | GoTrue, `users`, `lot_members` |
| `home` | Dashboard: occupancy + radial, space board (physical map), today KPIs, 7-day trend with week-over-week comparison, admin setup checklist, shift card, shortcuts; last KPIs cached on the device for offline | `occupancy_snapshot`, `dashboard_today`, `dashboard_trend`, `slot_board`, `lot_setup_status` |
| `spots` | Admin drag & drop map editor and bay layout, with a maintenance history per bay | `parking_spots`, `parking_spot_events`, `save/delete_parking_spot`, `list_spot_events` |
| `check_in` | Plate lookup, evidence photos, offline queue | `check_in`, `vehicles`, Storage `evidence` |
| `check_out` | Open sessions (paged), payment, receipt | `check_out`, `calculate_fare`, `open_sessions_view` |
| `records` | Site activity log with a plate/date filter, paging and evidence access | `session_records` |
| `policies` | Public legal policy / service contract | `public_lot_profile`, `reset_legal_policy` |
| `public_booking` | Public availability and anonymous reservations (`/reserve?lot=`) | `public_availability`, `public_create_reservation` |
| `vehicle_history` | Timeline, notes, blacklist, owner name/phone, evidence viewer, reprint, WhatsApp | `vehicle_history`, `update_vehicle_flags` |
| `vehicles` | Registry CRUD and paging | `vehicles` |
| `categories` / `tariffs` | Reference data per site, capacity | `categories`, `tariffs` |
| `monthly_passes` | Passes, charges, collection, expiry notices | `monthly_passes`, `monthly_pass_payments`, `register_pass_payment` |
| `shifts` | Open/close with expected-vs-counted and a denomination counter, movements, history filters, corrections, PDF | `shifts`, `cash_movements`, `shift_adjustments`, `list_shifts`, `adjust_shift` |
| `reports` | Revenue, occupancy, site comparison, hourly traffic, period comparison, WhatsApp metrics, PDF | `report_revenue(_all)`, `report_occupancy`, `report_hourly_traffic`, `report_period_comparison`, `report_whatsapp` |
| `notifications` | Inbox, bell, deep links, browser push toggle | `notifications`, `web_push_subscriptions` |
| `settings` | Per-site identity, branding, currency (COP/USD), retention, WhatsApp mode, police quadrant | `parking_settings`, `set_branding_logo` |
| `emergency` | One-tap call to the nearest police quadrant (123 fallback) | `parking_settings.police_phone` |
| `users` | Admin user management | `admin-users` Edge Function |
| `lots` | Sites and membership | `my_lots`, `create_lot`, `set_lot_member`, `list_lot_members` |
| `reservations` | Capacity holds | `category_reservations`, `create/cancel_reservation` |
| `audit` | Admin audit trail with free-text search and exports | `audit_log`, `list_audit_log` |
| `diagnostics` | Operational counters, client errors, WhatsApp queue | `diagnostics_snapshot`, `list_*` |
| `customer_messages` | Queue customer WhatsApp templates | `whatsapp_messages`, `enqueue_whatsapp_message` |
| `plate_scanning` | On-device OCR (Android) | ML Kit |
| `receipt_printing` | PDF + thermal receipts | `printing`, `bluetooth_print_plus`, receipts |
| `core` | Sync outbox, errors, l10n, theme, widgets, lot context | — |
| `app` | DI modules, router, shell | — |

**Edge Functions** (`supabase/volumes/functions`): `admin-users`,
`push-dispatch`, `evidence-archive`, `whatsapp-dispatch`, `public-evidence` (the `hello`/`main`
folders are Supabase scaffolding, not used by the app).

## 4. Architecture in one paragraph

The Flutter client talks only to the Envoy gateway (`:8000`) with a GoTrue JWT.
PostgREST exposes RLS-scoped tables and `rpc/*` functions; Storage serves
evidence/branding; Realtime streams notification rows; Edge Functions run with
the service key for operations that need it. Business rules that must be atomic
(billing, capacity, shifts, idempotent writes) live in SQL and derive the actor
from `auth.uid()`. The client keeps a Hive cache plus an outbox; queued writes
capture their idempotency key, client timestamp and site. See
[`architecture.md`](architecture.md) for diagrams and flows.

## 5. Security model

- GoTrue-only auth with 6-digit PINs, signup disabled, `/token` rate-limited.
- RLS everywhere; site data filtered by `current_lot_id()` (mandatory
  `x-lot-id`, validated membership) or membership for Storage objects.
- Writes through `security definer` RPCs; direct table writes are admin-only.
- The service-role key never reaches the client; Edge Functions verify the
  caller themselves.
- Audit log for reference data and user changes; secrets never audited.
- Rotation and leak-response procedures: [`runbook-secrets.md`](runbook-secrets.md).

## 6. Operations summary

| Concern | Where |
|---|---|
| Backups (DB + Storage) | `supabase/backup.sh`; nightly cron |
| Restore | `supabase/restore.sh` (+ runbook) |
| Prove a backup | `supabase/restore-drill.sh` (monthly) |
| Retention | cron: reservations, notifications, client errors, audit, WhatsApp, idempotency |
| Evidence files | `evidence-archive` function, daily, per-site window |
| Health | `supabase/healthcheck.sh` (+ webhook), `diagnostics.sh` |
| Observability | `client_error_reports` + `/diagnostics`, structured function logs |
| Secrets | `check-secrets.sh`, `rotate-pin.sh`, runbook |
| CI | analyze, tests, web build, compose, SQL/RLS, real-stack e2e |

Deployment: [`setup-cloud.md`](setup-cloud.md) (single VM + TLS proxy) and
[`infrastructure.md`](infrastructure.md) (services, ports, volumes).

## 7. Intentional limitations

- **Android + Web only.** No iOS target, no desktop target.
- **Internal receipts only.** No electronic invoicing.
- **COP or USD only** (site-level, integer minor units) and **ES/EN only**
  (system/Spanish default; English at key parity).
- **Operator-provided credentials** for FCM, VAPID and Meta WhatsApp; without
  them the features are inert (in-app notifications still work).
- **Evidence archival deletes objects.** Backups are the archive of record.
- **`pg_cron` is not available in the shipped image's app database**, so
  scheduled work runs from host cron (documented); the functions are the same.
- **Single currency and single tax regime** assumptions (no per-vehicle
  currency, no tax engine).
- **Physical bays are optional.** Without a map the board paints virtual
  capacity cells and capacity comes from Ajustes; with a map the bays define the
  capacity. Bicycles are not modelled.
- **Public booking captcha is opt-in.** `/reserve` always enforces one active
  hold per plate, two per phone, capacity and a per-lot ceiling of public
  holds per hour (default 20). The Cloudflare Turnstile check only protects a
  lot when the operator provides the keys (`TURNSTILE_SECRET_KEY`,
  `--dart-define=TURNSTILE_SITE_KEY`) **and** turns the requirement on for
  that lot (`set_public_booking_protection(true, null)`; there is no toggle in
  Ajustes yet). Without that, a caller who rotates plates and phones is
  stopped only by the hourly ceiling. There is no per-IP limit.
- **Beta Flutter SDK pinned**; analyzer output is limited to SDK deprecation
  infos until the pin moves to stable.

## 7.0 Booking waitlist (implemented)

When a category is full the public page offers the waitlist instead of a dead
end: the customer leaves name, mobile, plate, how long they can wait and how
long they want the space held. When capacity frees, the oldest turn of the
group gets a **real hold** (`source = 'waitlist'`), so the queue can never
overbook; claiming extends it and turns it into a normal web booking. The desk
sees the queue on the reservations board and can call, give the space or remove
a turn. Limits mirror the booking ones (captcha, hourly ceiling, one turn per
plate, two per mobile, a per-lot maximum). It is off per site
(`parking_settings.waitlist_enabled`), and WhatsApp notices are optional
(`waitlist_offer` template; without it the page polls and the desk calls).

## 7.1 Offline conflicts (implemented)

Reference entities (`vehicles`, `tariffs`, `categories`, `parking_settings`)
carry a `version` column. Queued edits send the version they were based on, so
a concurrent change is a conflict instead of an overwrite: disjoint field
edits merge automatically, overlapping ones are parked for the operator, who
resolves them per field from the sync badge (keep mine, keep theirs, or pick a
value for each field). Deletes are covered too (delete vs edit, edit vs
delete). Check-in and check-out are safe by idempotency, not by version. The
guard that refuses version-unaware clients is off by default and is switched
on per site with `set_row_version_policy(true)` once `min_app_version` is set.

## 8. Possible next steps (not planned work)

- Real FCM/Meta/VAPID credentials for production push and automated WhatsApp.
- Cold-storage archival for evidence files (currently deleted after retention).
- iOS target if required.
- Template management UI for automated WhatsApp.

## 9. Documentation map

| Document | Contents |
|---|---|
| [`../QUICKSTART.md`](../QUICKSTART.md) | Commands to get running |
| [`environment-guide.en.md`](environment-guide.en.md) / [`environment-guide.md`](environment-guide.md) | Onboarding, integrations, free vs paid (EN/ES) |
| [`setup-local.md`](setup-local.md) | Detailed local setup and troubleshooting |
| [`setup-cloud.md`](setup-cloud.md) | Production VM, TLS, hardening, upgrades |
| [`architecture.md`](architecture.md) | Components, layers, flows, trade-offs |
| [`infrastructure.md`](infrastructure.md) | Services, ports, volumes, operations, CI |
| [`database.md`](database.md) | ER diagram, tables, RPC catalog, RLS |
| [`runbook-restore.md`](runbook-restore.md) | Backups, drill, production restore |
| [`runbook-secrets.md`](runbook-secrets.md) | Secret inventory, rotation, leak response |
| [`agent-memory.md`](agent-memory.md) | Current invariants and gotchas |
| [`../PROGRESS.md`](../PROGRESS.md) | Capability changelog and decisions |
| [`../CHANGELOG.md`](../CHANGELOG.md) | Notable added/changed/fixed/security items |
| [`../openspec/`](../openspec) | Specs and archived changes |
