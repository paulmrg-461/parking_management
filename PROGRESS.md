# Project Progress

Spec-driven development via OpenSpec. Hexagonal Clean Architecture, feature-based,
SOLID, Clean Code, all code in English.

## Completed changes (archived)

| Change | Capabilities | Notes |
|---|---|---|
| `foundation` | `app-foundation`, `backend-foundation` | Monorepo scaffold (Flutter android+web + FastAPI/Postgres), DI, router, theme, Hive CE storage, JWT+Argon2id |
| `auth` | `auth`, `user-management` | PIN login, roles (admin/operator), persisted session, admin user CRUD |
| `vehicle-categories` | `vehicle-categories` | Category CRUD, offline cache |
| `tariffs` | `tariffs` | Tariff CRUD (hourly/daily/nightly/monthly), night window "HH:MM", validation |
| `vehicles` | `vehicles` | Vehicle CRUD, normalized unique plate, plate search |
| `plate-scanning` | `plate-scanning` | ML Kit OCR camera scan (one-shot `image_picker` capture), heuristic plate-block selection, shared `normalizePlate`, manual-entry fallback, `PlateScanningCubit`, `/scan` route |
| `check-in` | `check-in` | `parking_sessions`+`evidence_photos` (backend), `EvidenceStoragePort`/`LocalEvidenceStorage`, `POST/GET /check-ins`; Flutter `CheckInCubit`/`CheckInPage` (`/check-in`), reuses `/scan` + evidence photo capture, remote-only (no offline cache yet) |
| `billing` | `billing` | Pure `FareCalculator` (`app/application/billing_service.py`, no new tables): splits `[entry_time, exit_time)` by calendar day, then by the (possibly midnight-wrapping) night window; ceils to the hour once per calendar day per rate type (day vs night), not per sub-interval and not once for the whole stay; caps each calendar day's charge at the daily rate independently; `has_active_monthly_pass` flag short-circuits to `0` (no real subscription lookup yet — placeholder for `monthly-passes`). New `CategoryTariffs` domain aggregate bundles a category's hourly/daily/nightly `Tariff` rows (the real `Tariff` models one rate row at a time). Optional `GET /billing/quote` for a live fare preview. |
| `check-out` | `check-out` | Closes a `parking_sessions` row: adds `exit_time`/`amount_charged`/`ticket_number` (nullable, migration `0007`), `CheckOutService.close_session` calls `FareCalculator.calculate_fare_for_session` (`has_active_monthly_pass=False` placeholder, `# TODO(monthly-passes)`), ticket format `TCK-{id:06d}`. `POST /check-outs/{session_id}`. Flutter `CheckOutCubit`/`CheckOutPage` (`/check-out`) joins open sessions with `VehiclesCubit` for plate display, search-by-plate, receipt dialog via `CopFormatter`. Fixed a pre-existing latent bug: SQLite (test DB) drops tzinfo on `DateTime(timezone=True)` columns, causing naive/aware datetime comparison crashes once a computed (aware) `exit_time` was compared against a stored (naive-on-read) `entry_time` — normalized to UTC on read in the repository. |
| `monthly-passes` | `monthly-passes` | `MonthlyPass` (`vehicle_id`, `start_date`, `end_date`, `amount`, `active`), migration `0008`, `MonthlyPassRepository.get_active_for_vehicle(vehicle_id, on_date)` (`start_date <= on_date <= end_date AND active`). `MonthlyPassService` mirrors `TariffService`'s patch-merge shape exactly; reuses `check_in_service.VehicleNotFoundError` rather than a duplicate class. `GET /monthly-passes` (optional `vehicle_id` filter, any authenticated user), `POST`/`PATCH`/`DELETE /monthly-passes/{id}` (admin only) — same gating as `tariffs`. Wired into `check-out`: `CheckOutService` gained a `monthly_passes` constructor dependency and `close_session` now derives `has_active_monthly_pass` from a real lookup on `exit_time.date()` instead of the hardcoded `False`, removing the `# TODO(monthly-passes)` marker — a vehicle with an active pass is now checked out for `amount_charged == 0`. |
| `reports` | `reports` | Backend-only, read-only aggregation over existing tables — no new migration. New `ReportRepository` port (`app/domain/repositories.py`) + `RevenueReport`/`OccupancyReport` dataclasses (`app/domain/report.py`) + `SqlAlchemyReportRepository` (`app/infrastructure/repositories/report_repository.py`, joins `parking_sessions` -> `vehicles` -> `categories`, `func.sum`/`func.count`/`func.date` group-bys) + thin `ReportService` (validates `start_date <= end_date`, raises `InvalidReportRangeError` -> 422). `GET /reports/revenue?start_date=&end_date=` and `GET /reports/occupancy`, both gated `Depends(require_admin)` — deliberately stricter than `check-in`/`check-out`/`vehicles`' `get_current_user`-only gating, since this is manager-facing financial/operational data. `end_date` is treated as end-of-day (inclusive). |
| `offline-sync` | `offline-sync` | Flutter-only, deliberately narrow scope: outbox-queued `update`/`delete` for **vehicles, tariffs, categories only**. New `lib/core/sync/` (`PendingMutation`, `SyncOutbox`/`HiveSyncOutbox` — JSON-in-`Box<String>`, no Hive adapter/typeId — `SyncService`) + `lib/core/network/connectivity_service.dart` (`connectivity_plus`). On `NetworkFailure`, `Vehicle/Tariff/CategoryRepositoryImpl.update`/`delete` now merge the patch into the local Hive cache (optimistic, merged client-side in the repository — mirrors the backend's own patch-merge shape) and enqueue instead of rethrowing; `SyncService.flush()` replays each entry through the repository's own `update`/`delete` once online, and one still-failing entry never blocks another (no backoff/reordering — simple last-write-wins, matching the app's existing preference). At the time this row was written, `check-in`/`check-out`/`monthly-passes`/all `create` mutations were NOT covered — see `offline-check-in-out` below for check-in/check-out. |
| `offline-check-in-out` | `check-in`, `check-out`, `offline-sync` | Extends `offline-sync` to check-in (create) and check-out (close), the two kinds it originally excluded. **Check-out**: `CheckOutRepositoryImpl.checkOut` captures the device's local time at the moment of a `NetworkFailure`ed attempt and queues a `checkOut`/`close` `PendingMutation` carrying it as `client_exit_time` (keyed by the session's real id — no temp-id problem); replay reuses that *original* attempt time, never recaptures it, so the fare reflects when the operator acted, not when the device reconnected. Backend: `POST /check-outs/{session_id}` gains an optional JSON body (`CheckOutRequest.client_exit_time`), passed through to `CheckOutService.close_session`'s pre-existing (previously unused) `exit_time` override — omitted body keeps today's server-time behavior unchanged. The immediate receipt shows `pendingSync: true` with `amountCharged`/`ticketNumber` null — **no client-side fare calculation was added**; billing math stays backend-only (see its `design.md` Non-Goals: porting `FareCalculator`'s per-day/night-window/cap rules to Dart would create a second implementation that can drift from the backend's). **Check-in**: on `NetworkFailure`, `CheckInRepositoryImpl.createCheckIn` copies evidence photos from their transient picker location into `getApplicationSupportDirectory()/pending_check_ins/<clientRef>/` (new `lib/core/sync/pending_photo_storage.dart` — transient paths can be reclaimed by the OS before the queue drains), queues a `checkIn`/`create` `PendingMutation` (`entityId: null`), and returns an optimistic `ParkingSession` with a synthetic negative id and new `ParkingSessionStatus.pendingSync`. This sidesteps the generic "create needs server-id reconciliation" problem `offline-sync` flagged as a separate substantial feature: nothing on the client holds a reference to a session id after creation (open-sessions list is always refetched, never cached), so the synthetic id only has to be a valid list-row key until the next refresh — no reconciliation logic needed. `PendingMutation.entityId` widened to `int?` to represent this. `SyncService` gained `_replayCheckIn`/`_replayCheckOut` branches alongside the existing vehicle/tariff/category ones. |

| `add-parking-settings` | `parking-settings` | **Implemented (commit `05f6359`), pending manual smoke + archive.** Backend: singleton `parking_settings` row (migration `0012`), public `GET /api/settings` with ETag/304 (login branding pre-auth), admin-only `PATCH` (422 field validation), logo upload/serving `POST/GET /api/settings/logo` (magic-byte check, 5 MB, `logo_version` counter, `settings_storage_path` + `backend/data/.gitignore`). Flutter `features/settings`: entity/port/Dio+Hive adapters, repository `load()` = remote→cache→defaults and offline `save()` = optimistic cache + outbox (`MutationEntity.settings`, replayer in `sync_module.buildMutationReplayers`), root `BrandingCubit` (cache-first seed, refresh online, only emits when ≠ `defaults()` so fallback stays l10n). Surfaces: admin `/settings` deferred form + logo upload (`image_picker`, online-only), read-only `/contact` in **primary nav for both roles** (`operatorRoutes` allowlist, `tel:`/website/`wa.me` actions, `whatsappUrl()` digits-only helper), WhatsApp FAB in both shells (hidden when unconfigured), receipts via `EscPosGenerator.build(data, settings)` + `SystemDialogReceiptPrinter` (cache-first settings, logo in PDF, `PARQUEADERO` fallback when nothing cached), login header/home AppBar/`onGenerateTitle` use `BrandingState.titleFor(l10n)`. New dep: `url_launcher` (+ `url_launcher_platform_interface` dev). |

## Remaining changes (planned order)

All planned capabilities are now implemented — nothing remains in the roadmap.

**OpenSpec `add-parking-settings`**: only task **10.4 (manual smoke)** is open —
configure data on a device → contact page, WhatsApp link, login brand,
thermal + PDF receipts; airplane mode → load/edit settings, re-enable network
and confirm outbox replay. Then run `openspec archive add-parking-settings`.

## Completed: `migrate-to-supabase` (archived)

The app is now a Supabase-only stack: FastAPI, Alembic, Dio and Redis are gone.

- **Stack**: self-hosted Supabase (Postgres 17, GoTrue, PostgREST, Storage,
  Realtime, Studio, Edge Functions) vendored in `supabase/` and included from
  the root `docker-compose.yml`. The gateway owns `:8000`; secrets are
  generated by `supabase/generate-env.sh`.
- **Schema**: `supabase/migrations/` is the only schema owner (core tables,
  indexes, settings, seeds, RLS, buckets, RPCs), applied once by the
  `supabase-migrate` service with `schema_migrations` bookkeeping.
- **Auth**: GoTrue only. Usernames map to `<username>@parking.local`, PIN is
  the 6-digit password, and the `auth.users` trigger mirrors `public.users`.
  Admin user changes go through the `admin-users` Edge Function (service role
  stays server-side). Both the app token and the Supabase SDK session live in
  `flutter_secure_storage` (Keychain/Keystore/WebCrypto); Hive keeps only the
  profile, and logout signs out locally without touching the outbox.
- **Business logic in SQL**: `calculate_fare` (per-day night split, ceil per
  rate type, daily cap), `check_in`, `check_out` (row lock, monthly pass,
  ticket, clock-skew validation) and idempotency via `idempotency_keys`.
  Reports (`report_revenue`, `report_occupancy`), branding (`set_branding_logo`).
- **RLS**: `anon` has no table grants; `authenticated` reads reference data,
  admins write it, and operators cannot insert vehicles/profiles directly
  (check-in registers the vehicle inside the security-definer RPC). Session/
  evidence writes are RPC-only; users see their own profile (admins see all).
- **Storage**: evidence photos upload to the private `evidence` bucket before
  `check_in`; the logo lives in the public `branding` bucket.
- **Flutter**: every remote data source uses `supabase_flutter`
  (PostgREST/Storage/Functions); offline cache + outbox and the check-in/out
  replayers are unchanged in behaviour.
- **Validation**: wiped the database and re-ran the whole install; verified
  GoTrue login → RPC/PostgREST, RLS denials, idempotent check-in/check-out,
  reports, Storage uploads (private evidence/public branding) and the
  `admin-users` function. CI validates the Flutter app and the compose file.
- **Notifications**: `notifications` + `device_tokens` with RLS, admin
  check-in/check-out triggers, monthly-pass expiry alerts, Supabase Realtime
  for the in-app inbox/badge/banner, and an optional FCM `push-dispatch` Edge
  Function (service-role protected) driven by `supabase/notifications-cron.sh`.
  Flutter FCM registration is opt-in via Firebase dart-defines; without it the
  in-app center still works.
- **Operations**: check-out records the payment method (`cash`, `card`,
  `transfer`, `monthly_pass`, `exempt`; passes force `monthly_pass`) and
  receipts/reports show it; `/history` provides a per-plate timeline with
  visits/total spent and an offline cache; `notify_overstays()` alerts admins
  once a day for vehicles past `parking_settings.overstay_hours` (default 24).
- **Operations suite**: shifts/cash reconciliation (`open_shift`,
  `add_cash_movement`, `close_shift`, `list_shifts`; check-outs attach by exit
  time), per-category capacity with a serialized trigger and dashboard/full
  warnings, admin-only audited discounts (reason/actor/instant + report totals),
  and monthly-pass auto-renewal with linked passes and notifications.
- **UX/robustness pass**: live shift card on Home and a check-out banner when
  no shift is open; check-out plate search moved to the server with pagination
  (no more truncation at loaded pages); discount audit detail (reason/admin/
  timestamp) in reports; expired idempotency keys purged by the cron.
- **Pass charges and backups**: every pass (manual or auto-renewed) creates a
  pending charge; admins collect it from the monthly-passes screen with
  cash/card/transfer. Cash charges feed the shift drawer and expected cash;
  reports show pass revenue separately. `supabase/backup.sh` /
  `restore.sh` handle DB + Storage, and CI runs real migrations + SQL RPC/RLS
  tests against `supabase/postgres`.
- **Operational notes**: keep `.env` with backups (it is not included); schedule
  `supabase/backup.sh`; Android release builds need HTTPS in front of Envoy;
  run the notifications cron for pass expiry, overstays, renewals, idempotency
  cleanup and FCM delivery.

## Recent additions (post-roadmap, not OpenSpec changes)

- **Hardening pass (review findings)**: production config now rejects the
  `.env.example`/`change-me` secrets that used to pass the 32-byte check;
  offline check-ins carry `client_entry_time` end-to-end (Flutter form →
  replayer → `CheckInForm` → `CheckInService`, validated with the same 5-min
  skew rule as check-outs) so billing starts when the operator acted, not when
  the device reconnects; the first online check-in/check-out attempt now sends
  its `client_ref` as `Idempotency-Key`, so a lost response replays instead of
  dead-lettering; 403 maps to a non-retryable `ValidationFailure` (one
  forbidden mutation no longer stalls the outbox); sync starts after session
  restore, flushes on login, and the badge has a "Reintentar ahora" action;
  unpaged lookups (open sessions, vehicles, monthly passes) walk every backend
  page; the JWT lives in `flutter_secure_storage` while Hive keeps only the
  profile (legacy plaintext tokens are scrubbed on read), and logout clears
  reference-data caches + the ETag cache; every cubit extends `ResilientCubit`
  (late emits after `close()` are ignored), check-in/check-out submissions
  catch unexpected errors instead of spinning forever, and the check-out/scan
  screens are fully localized (Spanish default).

- **Live occupancy**: after a successful entry or exit, the home "Vehículos
  dentro" count refreshes (`DashboardCubit.load()` from
  `check_in_page`/`check_out_page` `_onSubmission` success branches).
  `DashboardCubit` moved from the `/` route to the `ShellRoute` so both pages
  can reach it (provider `create` runs once → bloc survives in-shell
  navigation); a failed refresh keeps the last known count instead of
  blanking/erroring the card (important for offline check-ins).

- **Receipts**: polished check-out/check-in receipts (`lib/core/widgets/receipt_card.dart`).
  Check-out shows a formatted summary (dates `dd/MM/yyyy HH:mm:ss`, duration
  `X h Y min`, a highlighted amount block) with a "Generar recibo" action that
  opens the full `ReceiptCard` (dashed divider, ticket, pending-sync pill).
- **Category seed**: `supabase/migrations/0004_seed_reference_data.sql`
  idempotently creates the standard categories (moto, car, camioneta, camion,
  bus) for a fresh DB; the check-in form surfaces a message when none exist.
- **l10n regression fix**: `check_in_page`/`check_out_page`/`vehicle_lookup_section`
  had been rewritten with hardcoded English; restored `context.l10n.*` (Spanish
  default) and the inline plate-scan flow (`PlateScanningCubit` +
  `captureAndScan`), and fixed the two widget tests that pumped bare
  `MaterialApp` without localization delegates.
- **Receipt printing**: `lib/features/receipt_printing/` adds an "Imprimir"
  action on every receipt — a system PDF print (`printing` package, all
  platforms) and Bluetooth thermal printers (`bluetooth_print`, classic SPP,
  Android). ESC/POS lines are built by `ReceiptLineBuilder`; discovery/print
  state lives in `PrinterCubit`. Bluetooth permissions added to the Android
  manifest.

- **Ops/UX medium batch**: pass charges are backfilled for passes that predate
  the charge table (`0017`); closed shifts can be corrected by an admin with a
  mandatory reason, keeping old/new reconciliation in `shift_adjustments`
  (`0018`, `rpc/adjust_shift`); cash operations (open/close/movement/adjust and
  pass collection) are disabled offline with an explicit banner instead of
  being queued; notifications deep-link by type (`shift_closed` → `/shift`,
  pass events → `/monthly-passes`, vehicle events → `/history?plate=…`); and
  admins can reset a PIN or delete a user from the users list, with
  `LastAdminError`/`CannotDeleteSelfError` enforced server-side in the
  `admin-users` Edge Function.

- **Product batch (low priority)**: a lost ticket charges the full daily tariff
  (or `parking_settings.lost_ticket_fee`) with a mandatory reason (`0019`);
  vehicles carry notes and an admin-only blacklist that blocks check-in
  (`0020`); capacity reservations hold slots and the check-in dropdown disables
  full categories before submitting (`0021`); printed receipts follow the app
  language through `ReceiptLabels`; list screens use pulsing skeletons that
  honor reduce-motion; and browsers can subscribe to Web Push (VAPID) — the
  service worker, `web_push_subscriptions`, `push-dispatch` delivery and the
  inbox toggle are in place, while the VAPID/FCM keys remain operator-provided
  (`0022`).

- **Multi-lot (phases 1–3)**: `parking_lots` + `lot_members` with a seeded
  `default` lot; `lot_id` on every site-owned table (categories, tariffs,
  sessions, shifts, passes, pass payments, reservations, settings,
  notifications) and unique keys rebuilt as `(lot_id, …)` (`0023`);
  `current_lot_id()` / `is_lot_admin()` / `require_lot_admin()` plus lot CRUD
  and membership RPCs, re-scoped policies and every RPC/report filtering the
  active lot (`0024`); offline check-in/check-out carry the captured lot and
  `resolve_lot()` validates it on replay (`0025`). Flutter adds `LotContext`
  (persisted active lot wired into the Supabase header), a shell lot bar for
  multi-site users and an admin `/lots` page. Remaining in the OpenSpec change:
  lot-keyed Hive cache paths, a consolidated-report toggle, per-lot receipts
  lot; settings/branding read and write the active lot's row; category, tariff,
  monthly-pass and notification caches are keyed per lot; the reports screen
  adds a consolidated "Todas las sedes" switch (`report_revenue_all`); `/lots`
  manages members per site and `admin-users` accepts `lot_id`; receipts print
  the active lot's settings header. Hardening pass: per-lot branding (logo object
  and RPC scoped to the active site, reloaded on switch), evidence object reads
  limited to the active lot's sessions, CI now runs on `feature/**`, GoTrue PIN
  minimum raised to 6 with the `/token` rate-limit header configured, and the
  web/Android metadata no longer ships Flutter defaults. Remaining: the contract
  migration that drops the missing-header fallback (deliberate follow-up).

- **Operational batch**: revenue reports and the shift reconciliation export as
  PDF (share/print sheet, per-site breakdown included); the admin shift history
  filters by date range (`list_shifts(limit, start, end)`); retention jobs for
  expired reservations and stale notifications run from the cron script (and
  through pg_cron when the database has it).

- **Observability**: uncaught app errors land in `client_error_reports`
  (`report_client_error`, throttled/bounded, admin-readable, 30-day purge) and
  are wired to Flutter's global handlers; Edge Functions emit one structured
  JSON log line per request; `supabase/healthcheck.sh` checks services,
  endpoints and backlog with an optional alert webhook, and
  `supabase/diagnostics.sh` prints the support snapshot.

- **Admin audit trail**: `0031` adds `audit_log` with a generic row trigger on
  categories, tariffs, vehicles, passes, settings, lots and memberships (actor
  from `auth.uid()`, changed columns only, lot stamped), explicit audit for
  user actions in `admin-users`, and an admin `/audit` screen with table/date
  filters and a before/after dialog. Purged after 365 days by the cron.

- **End-to-end tests**: `supabase/tests/e2e.sh` (curl: login → check-in →
  check-out → report → history) and `test/integration/supabase_flow_test.dart`
  (pure-Dart Supabase client) run against a real stack locally or in CI
  (compose up + admin + both suites).

- **Multi-lot contract**: `0032` makes `x-lot-id` mandatory (no fallback),
  rewrites the overstay cron to evaluate every site with its own threshold, and
  the app selects the lot before exposing the session. The OpenSpec change is
  archived at `openspec/changes/archive/2026-10-23-add-multi-parking-lot`
  and the capability lives in `openspec/specs/parking-lots`.

- **Evidence retention**: `parking_settings.evidence_retention_days` (0 = keep,
  editable in settings) plus the `evidence-archive` Edge Function, which
  deletes Storage objects and rows for sessions past the window (service-role
  only, daily cron, dry-run supported). Storage reads now use the
  membership-based `can_read_evidence()` helper, since the Storage API does not
  forward `x-lot-id`.

- **Admin diagnostics screen**: `/diagnostics` shows migrations, active sites,
  open sessions/shifts with age warnings, pending payments, reservations,
  idempotency keys, notification backlog, storage usage per bucket and the last
  7 days of client error reports (stack + context). Backed by
  `rpc/diagnostics_snapshot` and `rpc/list_client_error_reports`.

- **Audit exports**: `/audit` filters by actor (`p_actor` on
  `list_audit_log`) and exports the current view as PDF (share/print) or CSV
  (clipboard).

- **Product polish**: vehicle history tags each session with its site and adds
  a per-site filter (plus "visits at this site" when the plate has been
  everywhere); home gained a "today" card with revenue, cash, pass collections,
  entries and exits (`rpc/dashboard_today`, local-midnight window).

- **Restore drill**: `supabase/restore-drill.sh` restores the latest (or a
  given) backup into a scratch database and compares migrations, RPCs, RLS
  policies, grants, row counts and the storage archive, without touching
  production. The real restore now runs `pg_restore` as `supabase_admin`
  (restoring as `postgres` lost every grant), and
  `docs/runbook-restore.md` documents the drill, the production restore, a
  new-host recovery and the verification checklist. CI runs the drill.

## Infra/tooling (not OpenSpec capabilities — repo scaffolding)

- **Docker**: root `docker-compose.yml` includes the official self-hosted
  Supabase stack (`supabase/`) plus the `supabase-migrate` one-shot schema
  runner. `docker compose up -d --build` is the only command needed.
- **First-admin bootstrap**: `supabase/create-operator.sh` creates the GoTrue
  user and the `auth.users` trigger mirrors the profile.
- **Flutter config**: `--dart-define=SUPABASE_URL=...` and
  `SUPABASE_ANON_KEY=...`; the app fails fast if either is missing.
- **Android release signing**: `android/app/build.gradle.kts` reads a
  gitignored `android/key.properties` when present (see
  `android/key.properties.example`), falling back to debug signing when it
  doesn't — no keystore is checked into this repo.
- **CI**: `.github/workflows/ci.yml` runs `flutter analyze`/`flutter test`/
  web build plus a compose config validation on push/PR to `main`.
- **License**: MIT (`LICENSE`).
- **Git config note**: this repo's `android/`, `ios/`, `linux/`, `macos/`,
  `windows/` platform directories were never tracked in git — traced to a
  sandbox-wide `core.excludesFile` (unrelated to this project) blanket-
  excluding platform folders, not a deliberate `.gitignore` decision. Fixed
  by setting this repo's local `core.excludesFile` to `/dev/null` (each
  platform dir's own nested `.gitignore` — already present, e.g.
  `android/.gitignore` excluding `local.properties`/`key.properties`/
  keystores — still applies normally) and committing the previously-invisible
  platform scaffolding. Worth knowing if a *fresh* clone/sandbox ever again
  reports these directories as "untracked" unexpectedly.

## Key technical decisions

- Local store: **Hive CE** (not Isar — Isar's generator is EOL/incompatible with modern source_gen).
- State: **flutter_bloc + Equatable** (not Freezed — Freezed stable pins analyzer <11, conflicting with modern DB generators).
- DI: **get_it manual registration** (not injectable — source_gen conflict with Isar/Hive).
- Offline-first: session persists in Hive; reads cached with network fallback. Mutations are remote-only for `check-in`/`check-out`/`monthly-passes` and every `create` (correctness/complexity reasons, see `offline-sync`'s `design.md` Non-Goals); `update`/`delete` on vehicles/tariffs/categories are outbox-queued and replayed on reconnect (`offline-sync`).
- Login requires connectivity (GoTrue is the authority); session survives restarts offline.
- COP currency via `intl`; night tariff = time window that replaces day tariff.
- Hive codegen: single `@GenerateAdapters` file at `lib/app/di/hive_adapters.dart`.
- Home occupancy: `DashboardCubit` is provided at the go_router `ShellRoute` (not on the `/` route), so the check-in/check-out pages can refresh the "Vehículos dentro" count after a submission; a failed refresh keeps the last known count instead of blanking the card (provider `create` runs once, so the bloc survives in-shell navigation).

## Test counts

- Flutter (`flutter test`): 538 passed (plus 1 integration test that runs only against a live stack). `flutter analyze`: 0 errors/warnings
  (98 SDK-deprecation/const infos under the local Flutter 3.50 beta; CI pins
  3.49 where the baseline is clean).
- SQL/compose: validated against the running Supabase stack and by
  `supabase/tests/run.sh` (migrations, capacity, shifts/arqueo, discounts,
  pass charges and RLS) in CI.

## Layer map (Flutter feature slice)

`domain/` (entities + ports) -> `application/` (cubits) -> `infrastructure/` (Supabase + Hive adapters) -> `presentation/` (pages).

## Supabase layout

`supabase/migrations/` (schema, RLS, RPCs, seeds) -> `supabase/volumes/functions/`
(admin-users) -> `supabase/docker-compose.yml` (official stack included from the
root compose). The Flutter client never sees the service-role key.
