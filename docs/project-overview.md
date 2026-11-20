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
| Customer feedback | Complete (public survey + admin satisfaction report) | SQL + widget tests |
| Online payments | Complete, inert without Wompi keys (`/evidence` pay panel, webhook, reconcile job, settlement) | SQL + Deno + widget tests |
| Pass auto-renewal | Complete, inert without Wompi keys (`/renew` link, reminders, online settlement) | SQL + Deno + widget tests |
| Merchant agreements | Complete (`/merchants`, `/validate` link + PIN, settlement, fare_quote) | SQL + widget tests |
| Dynamic pricing | Complete, inert by default (rules, locked rate at entry, simulation, impact) | SQL + widget tests |
| Loyalty rewards | Complete, inert by default (visit accrual, reward redemption, `/loyalty`, expiry job) | SQL + widget tests |
| Electronic invoicing | Complete, inert by default (`mode = off`, provider optional; every DIAN rule an ASSUMPTION) | SQL + Deno + widget tests |
| Report assistant | Complete, inert without `DEEPSEEK_API_KEY` (tool allowlist, verified figures, budget) | SQL + Deno + widget tests |
| Damage comparison | Complete, inert without a key (exit photos, advisory AI comparison, human review) | SQL + Deno + widget tests |
| Device gateway | Complete (registry, keys, `/devices` admin, transport, offline alerts) | SQL + Deno + widget tests |
| Backups / restore | Complete, with a safe drill | Drill executed against a real backup |
| Secrets / PIN operations | Complete (scripts + runbook) | PIN rotation verified live |
| E2E and CI | Complete (API + Flutter client + device protocol, real stack) | CI job `supabase-e2e`; local `integration_test/app_flow_test.dart` |

Quality snapshot (2026-11-20, local stack): **1981 Flutter tests + 2 integration
tests**, **179 Deno tests** (unit, replay, eval guards, the device gateway and
the barrier signing/vector), SQL/RLS suite green over `0001`-`0138`, web
builds green, analyzer with **0 errors and 0 warnings** (only SDK deprecation
infos from the pinned beta channel), restore drill green.

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
| `feedback` | Public satisfaction survey (`/feedback?session=&plate=`) and the admin report (`/satisfaction`) | `session_feedback`, `public_feedback_session`, `public_submit_feedback`, `feedback_summary` |
| `vehicle_history` | Timeline, notes, blacklist, owner name/phone, evidence viewer, reprint, WhatsApp | `vehicle_history`, `update_vehicle_flags` |
| `vehicles` | Registry CRUD and paging | `vehicles` |
| `categories` / `tariffs` | Reference data per site, capacity | `categories`, `tariffs` |
| `monthly_passes` | Passes, charges, collection, expiry notices | `monthly_passes`, `monthly_pass_payments`, `register_pass_payment` |
| `shifts` | Open/close with expected-vs-counted and a denomination counter, movements, history filters, corrections, PDF | `shifts`, `cash_movements`, `shift_adjustments`, `list_shifts`, `adjust_shift` |
| `reports` | Revenue, occupancy, site comparison, hourly traffic, period comparison, WhatsApp metrics, PDF | `report_revenue(_all)`, `report_occupancy`, `report_hourly_traffic`, `report_period_comparison`, `report_whatsapp` |
| `notifications` | Inbox, bell, deep links, browser push toggle | `notifications`, `web_push_subscriptions` |
| `settings` | Per-site identity, branding, currency (COP/USD), retention, WhatsApp mode, police quadrant, online payments | `parking_settings`, `set_branding_logo` |
| `online_payments` | Public pay-from-phone panel, intent polling and the pay-online receipts/refunds review | `payment-intent`, `payment-webhook`, `payments-reconcile` (Edge Functions), `session_settlement`, `payment_intent_status`, `report_online_payments` |
| `pass_renewal` | Public token-keyed renewal page (`/renew?t=`) and the admin "send renewal link" action | `pass_renewal_offers`, `public_pass_renewal`, `pass-renewal-intent` (Edge Function), `settle_pass_renewal`, `queue_pass_renewal_reminders` |
| `merchants` | Agreements, show-once credentials, per-vehicle policy, settlement and the public `/validate?m=` page | `merchants`, `merchant_credentials`, `merchant_validations`, `fare_quote`, `save_merchant`, `merchant_validate`, `report_merchant_settlement` |
| `pricing` | Dynamic rates: rules, guard rails, simulation, impact and the check-in price chip | `pricing_rules`, `pricing_lock`, `pricing_quote`, `pricing_simulate`, `report_pricing_impact`, `public_availability` price keys |
| `devices` | Per-lot hardware registry, key rotation, heartbeat/offline alerts, the `device-gateway` transport and the `/devices` admin screen | `lot_devices`, `device_events`, `register_lot_device`, `device_accept_request`, `device_heartbeat`, `notify_offline_devices` |
| `damage_comparison` | Exit photos, advisory AI comparison of entry/exit photos, the `/damage-comparison` page and the human review | `damage_comparisons`, `damage_findings`, `add_exit_evidence`, `begin/get_damage_comparison`, `review_damage_finding`, `damage-compare` |
| `lpr_gate` | Fixed plate camera: server-side voting and decisions, `/gate` inbox, assist/auto settings, snapshot evidence and the device protocol | `lpr_settings`, `lpr_camera_config`, `lpr_reads`, `lpr_events`, `device_ingest_lpr_read`, `confirm_lpr_entry`, `expire_lpr_events`, `device-gateway /v1/lpr/*` |
| `barrier_control` | Boom barriers: configured rules, signed single-use commands, manual open with reason, device events and firmware releases | `barrier_config`, `barrier_commands`, `barrier_events`, `device_firmware`, `barrier_issue_command`, `request_manual_barrier_open`, `device-gateway /v1/barrier/*` |
| `report_assistant` | Natural-language questions over the report RPCs with a verified figure/source for each number (`/report-assistant`) | `ai_requests`/`ai_limits`, `ai_budget_*`, `report-assistant` Edge Function, `report_revenue` and the other report RPCs |
| `invoicing` | Fiscal issuer/resolutions, document outbox, credit notes and the admin list (`/invoicing`) | `fiscal_settings`, `fiscal_resolutions`, `fiscal_documents`, `issue_fiscal_document`, `list_fiscal_documents`, `request_credit_note`, `fiscal-dispatch` |
| `loyalty` | Visit program, reward redemption, member corrections and the impact report (`/loyalty`) | `loyalty_accounts`, `loyalty_rewards`, `loyalty_visits`, `loyalty_adjustments`, `fare_reward_step`, `loyalty_plate_status`, `choose_loyalty_redemption`, `report_loyalty`, `list_loyalty_accounts` |
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
`push-dispatch`, `evidence-archive`, `whatsapp-dispatch`, `public-evidence`,
`public-booking`, `payment-intent`, `payment-webhook`, `payments-reconcile`,
`pass-renewal-intent`, `fiscal-dispatch`, `report-assistant`
(the `hello`/`main` folders are Supabase scaffolding, not used by the app).

## 4. Architecture in one paragraph

The Flutter client talks only to the Envoy gateway (`:8000`) with a GoTrue JWT.
PostgREST exposes RLS-scoped tables and `rpc/*` functions; Storage serves
evidence/branding; Realtime streams notification rows; Edge Functions run with
the service key for operations that need it. Business rules that must be atomic
(billing, capacity, shifts, idempotent writes) live in SQL and derive the actor
from `auth.uid()`. The client keeps a Hive cache plus an outbox; queued writes
capture their idempotency key, client timestamp and site. Online payments keep
the gateway contracts inside Edge Functions: the browser never sees a Wompi
key, the redirect page only polls, and the signed webhook is what marks a
session as paid. See
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
| Loyalty expiry | cron: `loyalty_expire_rewards` marks rewards past their validity `expired` |
| Evidence files | `evidence-archive` function, daily, per-site window |
| Health | `supabase/healthcheck.sh` (+ webhook), `diagnostics.sh` |
| Observability | `client_error_reports` + `/diagnostics`, structured function logs |
| Secrets | `check-secrets.sh`, `rotate-pin.sh`, runbook |
| CI | analyze, tests, web build, compose, SQL/RLS, real-stack e2e |

Deployment: [`setup-cloud.md`](setup-cloud.md) (single VM + TLS proxy) and
[`infrastructure.md`](infrastructure.md) (services, ports, volumes).

## 7. Intentional limitations

- **Android + Web only.** No iOS target, no desktop target.
- **Electronic invoicing is opt-in and provider-dependent.** Every DIAN rule
  (document types, IVA rate, codes, CUFE/CUDE, resolution fields) is an
  ASSUMPTION that the owner and their accountant must confirm; the shipped
  default is `mode = 'off'` and, without `FISCAL_PROVIDER_*`, documents stay
  `pending` instead of being transmitted.
- **COP or USD only** (site-level, integer minor units) and **ES/EN only**
  (system/Spanish default; English at key parity).
- **Operator-provided credentials** for FCM, VAPID and Meta WhatsApp; without
  them the features are inert (in-app notifications still work).
- **Evidence archival deletes objects.** Backups are the archive of record.
- **Customer feedback is online-only and unmoderated.** The answer needs the
  server to verify the session and the one-answer rule, there is no reply or
  deletion flow, and low ratings do not trigger an alert yet.
- **`pg_cron` is not available in the shipped image's app database**, so
  scheduled work runs from host cron (documented); the functions are the same.
- **Single currency and one tax rule.** Prices are tax-inclusive; the fiscal
  document derives `tax_base = round(total × 10000 / (10000 + rate))` and
  `tax = total − tax_base`, with one rate per lot (no per-category rates,
  withholdings or tax engine).
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

## 7.03 Cash anomaly detection (implemented)

The admin no longer has to find cash leaks by browsing. Eight deterministic
rules run on a schedule over the lot's own rows: repeated shift shortages per
operator, a lost-ticket rate above the lot baseline, adjustments made after a
shift closed, zero-charge check-outs that are not monthly passes, a lost-ticket
fee on a very short stay, an admin's discount share, shifts left open and
vehicles inside for many days. Each finding is stored once (deduped per lot and
subject), can be acknowledged or dismissed with a note (audited), and one
summary notification per run reaches the lot's admins. Thresholds are
per-lot and admin-only; detection and retention run from the jobs container.

## 7.05 Occupancy forecast (implemented)

"Will it be full at 6 pm?" is answered from the lot's own history: per group,
weekday and hour the system keeps the **median** of the last K same-weekday
days and blends it with today's live deviation (the deviation fades 15 % per
hour), clamped to capacity. The home dashboard shows the next 12 hours with the
estimated "full at" time and a confidence label; the public page shows an
aggregate strip (levels, time, confidence) that never exposes counts; the
reports screen can replay the algorithm over past weeks to see whether the live
blend beats the profile alone. Below the minimum history the forecast is not
shown instead of guessed. Holidays are out of scope, reservation holds are not
subtracted, and the forecast is never cached (it is time-sensitive).

## 7.07 Customer feedback (implemented)

Each check-out receipt can carry a survey link (QR on the PDF/thermal receipt
and a line in the manual WhatsApp receipt, only when `APP_URL` is configured).
The customer opens `/feedback?session=…&plate=…`, sees the site name and rates
the visit from 1 to 5 with an optional comment. The plate is the access key, a
session can be answered once, and only closed sessions are rateable, so a
receipt cannot be used to score a visit that has not ended. The admin page
`/satisfaction` turns the answers into an average, a response rate against the
lot's check-outs, the count of low ratings (≤ 3), the 1..5 distribution and the
latest comments, for 7, 30 or 90 days. The survey is online-only and there is no
moderation, reply or export yet.

## 7.08 Loyalty rewards (implemented)

Every N paid visits a plate earns one reward, per lot and inert until
`loyalty_enabled` is on. A visit counts only when the stay closes with real
money (`amount_charged > 0` and at or above `loyalty_min_amount`), at least
`loyalty_min_minutes` long, not a pass/lost/exempt settlement, not the second
visit of the same business day, and not the visit that just redeemed a reward.
Progress is a counter (`0`..`N-1`) with a ledger (`loyalty_visits`) that
explains every number; a reward snapshots its kind and value when earned, so
later settings changes cannot inflate or cheat old rewards. The reward is one
server-computed line of `fare_quote` (after merchant benefits, capped so it
never subsidises an online payment already made) and one reward per session,
oldest first, non-expired. `auto` mode applies it unless the operator taps “No
usar ahora”; `operator` mode applies it only on “Usar recompensa”. The trigger
that writes the ledger never blocks a check-out: a loyalty failure is stored as
a skipped visit with reason `error`. `/loyalty` shows the program, the members
with a bounded, reasoned progress correction, and the impact report. A manual
correction can move progress but can never mint a reward.

## 7.12 Device gateway (backend, no user accounts for devices)

Cameras, barriers and sensor hubs are registered per lot with a `pkd_…` API key
whose SHA-256 hash is stored (the plaintext is shown once, on registration or
rotation). A device never gets a GoTrue user or a lot header it can choose: the
`device-gateway` Edge Function resolves the lot from the registry, compares the
key in constant time, and enforces a strictly increasing `X-Device-Seq`, a ±5
minute timestamp (`max_client_clock_skew()`) and a per-device rate window before
calling the service-role RPCs. Every registration, rotation, enable/disable,
rename, delete, rejected request and online/offline transition lands in
`device_events`. `notify_offline_devices` alerts the lot admins once per
silence. `/v1/time` and `/v1/heartbeat` are the only routes in this change; the
camera, barrier and sensor changes extend the same route table. The Flutter
admin screen is the next batch.

## 7.11 Damage comparison (backend, inert without a key)

Exit photos are optional evidence rows (`phase = 'exit'`) captured online at
check-out through `add_exit_evidence`; `check_out` is not modified. A comparison
reads up to five entry and five exit photos with the caller's JWT, downscales
them through Storage rendering, and asks the vision model (DeepSeek
`deepseek-flash`) for a structured list of findings. The code downgrades any
"new" finding that lacks a clear entry/exit pair, low confidence or a confirmed
same-vehicle answer to "uncertain", caps the list at 12 and computes the overall
verdict itself. An all-clear is only possible with a confirmed same vehicle, at
least three zones visible in both sets and no uncertain finding; anything less
is "insufficient evidence", never a silent "no new damage". The result is
stored by the service role only, so operators cannot forge a finding; operators
confirm or dismiss each finding with a mandatory note (audited), and an admin
can re-run. The comparison is advisory: it never changes the charge, the
discount or the blacklist. The settlement dialog captures optional exit photos
with angle guidance, the evidence sheet groups photos by phase and offers the
compare action, and the `/damage-comparison` page shows the verdict and
findings.

## 7.12 LPR gate (software complete, hardware pending)

A fixed camera posts plate reads to the device gateway; the server owns the
decision. Reads are serialised per camera, normalised with the same rule as
`check_in`, stored even when they are late or low-confidence, debounced by
cooldown and only decided after the configured votes. The decision table covers
assist mode, automatic check-in attributed to the lot's system operator,
unknown plates with a default category, blacklist, duplicate sessions, a full
lot and the error path; an exit only raises an alert and never closes or
charges a session. Pending and blocked reads notify every active member once,
and the `/gate` inbox confirms (with plate correction), dismisses or opens the
check-out for an unpaid exit. Admins configure mode and thresholds and assign
each camera's direction in `/gate-settings`; auto mode asks for confirmation
because a spoofed plate could open a session unattended. Snapshots become
ordinary evidence photos once a session exists and are purged with the events.
What remains is the Jetson reference service (`edge/lpr/`) and the physical
validation; the protocol and the rest are covered by SQL, Deno, widget and
end-to-end tests.

## 7.13 Barrier control (software complete, firmware pending)

The barrier is the physical enforcement of the system: it opens for a
check-in, a paid exit, a recognised pass holder (opt-in) and a logged manual
request. Every opening is a command row with its source, session, camera event,
operator and reason, delivered at most three times inside a 30-second TTL and
signed with Ed25519 by the gateway; the firmware verifies the signature, the
device id, the TTL and the replay state before energising the relay. The
triggers that issue commands never roll back a check-in or a check-out, an
offline barrier records an expired command and alerts, and the operator page
asks for a reason, notifies the admins, limits ten manual openings per user
per hour and tracks the command until it executes. Admins configure the rules
and timings; firmware releases are platform-admin only. What remains is the
ESP32-S3 firmware and the physical commissioning.

## 7.10 Report assistant (implemented, inert without a key)

An admin asks "how much did motorcycles make last month?" from `/reports` and
gets an answer whose numbers are **not written by the model**: the assistant may
only call nine reviewed read-only report RPCs (revenue, hourly traffic,
reservations, WhatsApp, occupancy, capacity, today, daily trend, shifts) with the
caller's JWT and `x-lot-id` over a `GET`, so RLS and the admin guards keep
deciding what is visible. The model returns figure recipes (tool call id + field
path) and the Edge Function resolves them against the real RPC JSON with
integer math; the Flutter client re-verifies each figure from its raw sources
and shows the RPC, arguments and path. Plates, owners, usernames and free-text
notes are projected out and the question is redacted before it leaves the
server. Cost is bounded by a per-lot daily request/token budget reserved before
each call. The provider is DeepSeek (OpenAI-compatible) and the feature is
inert without `DEEPSEEK_API_KEY`; if that key is absent the page says "not
enabled" and no reservation or outbound call happens.

## 7.09 Electronic invoicing (implemented, inert by default)

A separate call after check-out (or the cron sweeper in `always` mode) creates
a numbered fiscal document: a POS equivalent for a final consumer, an invoice
when the operator captures the optional customer data, or a credit note when an
admin reverses an accepted document. Numbering is gap-free under the
resolution's row lock, documents are immutable once numbered, and every
provider rule sits behind `fiscal-dispatch`'s `FiscalProvider` port with one
generic REST adapter. The app never talks to the DIAN or holds the provider
token. `mode` defaults to `off`; with no `FISCAL_PROVIDER_*` credentials the
dispatcher answers `configured: false` and documents remain `pending` in
`/invoicing`. The tax is extracted from the amount already charged
(`tax_base = round(total × 10000 / (10000 + rate))`), so the document total
always equals what the customer paid. Receipts and the history reprint show the
number, CUFE and QR once accepted, or "Documento electrónico en proceso" while
the provider has not answered. Every DIAN-specific rule is an ASSUMPTION
pending the owner's and accountant's written confirmation.

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
