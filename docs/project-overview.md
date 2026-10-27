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

Quality snapshot (2026-10-24, local stack): **668 Flutter tests + 1 integration
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
| `home` | Dashboard: occupancy, today KPIs, shift card, shortcuts | `occupancy_snapshot`, `dashboard_today` |
| `check_in` | Plate lookup, evidence photos, offline queue | `check_in`, `vehicles`, Storage `evidence` |
| `check_out` | Open sessions (paged), payment, receipt | `check_out`, `calculate_fare`, `open_sessions_view` |
| `vehicle_history` | Timeline, notes, blacklist, phone, reprint, WhatsApp | `vehicle_history`, `update_vehicle_flags` |
| `vehicles` | Registry CRUD and paging | `vehicles` |
| `categories` / `tariffs` | Reference data per site, capacity | `categories`, `tariffs` |
| `monthly_passes` | Passes, charges, collection, expiry notices | `monthly_passes`, `monthly_pass_payments`, `register_pass_payment` |
| `shifts` | Open/close, movements, history filters, corrections, PDF | `shifts`, `cash_movements`, `shift_adjustments`, `list_shifts`, `adjust_shift` |
| `reports` | Revenue, occupancy, site comparison, WhatsApp metrics, PDF | `report_revenue(_all)`, `report_occupancy`, `report_whatsapp` |
| `notifications` | Inbox, bell, deep links, browser push toggle | `notifications`, `web_push_subscriptions` |
| `settings` | Per-site identity, branding, retention, WhatsApp mode | `parking_settings`, `set_branding_logo` |
| `users` | Admin user management | `admin-users` Edge Function |
| `lots` | Sites and membership | `my_lots`, `create_lot`, `set_lot_member`, `list_lot_members` |
| `reservations` | Capacity holds | `category_reservations`, `create/cancel_reservation` |
| `audit` | Admin audit trail and exports | `audit_log`, `list_audit_log` |
| `diagnostics` | Operational counters, client errors, WhatsApp queue | `diagnostics_snapshot`, `list_*` |
| `customer_messages` | Queue customer WhatsApp templates | `whatsapp_messages`, `enqueue_whatsapp_message` |
| `plate_scanning` | On-device OCR (Android) | ML Kit |
| `receipt_printing` | PDF + thermal receipts | `printing`, `bluetooth_print_plus`, receipts |
| `core` | Sync outbox, errors, l10n, theme, widgets, lot context | — |
| `app` | DI modules, router, shell | — |

**Edge Functions** (`supabase/volumes/functions`): `admin-users`,
`push-dispatch`, `evidence-archive`, `whatsapp-dispatch` (the `hello`/`main`
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
- **COP only, ES/EN only** (Spanish default; English at key parity).
- **Operator-provided credentials** for FCM, VAPID and Meta WhatsApp; without
  them the features are inert (in-app notifications still work).
- **Evidence archival deletes objects.** Backups are the archive of record.
- **`pg_cron` is not available in the shipped image's app database**, so
  scheduled work runs from host cron (documented); the functions are the same.
- **Single currency and single tax regime** assumptions.
- **Beta Flutter SDK pinned**; analyzer output is limited to SDK deprecation
  infos until the pin moves to stable.

## 8. Possible next steps (not planned work)

- Real FCM/Meta/VAPID credentials for production push and automated WhatsApp.
- Cold-storage archival for evidence files (currently deleted after retention).
- Historical per-site metrics dashboard (today's KPIs exist; trends do not).
- iOS target if required.
- Template management UI for automated WhatsApp.
- Conflict resolution for offline reference-data edits (last-write-wins today).

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
