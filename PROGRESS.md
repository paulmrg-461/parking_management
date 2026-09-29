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

## Recent additions (post-roadmap, not OpenSpec changes)

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
- **Category seed**: `backend/scripts/seed_categories.py` idempotently creates
  the standard categories (moto, car, camioneta, camion, bus) for a fresh DB,
  and the check-in form surfaces a message when none exist (instead of a
  silently disabled dropdown).
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

## Infra/tooling (not OpenSpec capabilities — repo scaffolding)

- **Docker**: `backend/Dockerfile` (uv-based) + root `docker-compose.yml`
  (`db` postgres:16 + `backend`, migrations run automatically via
  `backend/docker-entrypoint.sh`). `docker compose up --build` is the
  fastest path to a running backend.
- **First-admin bootstrap**: `backend/scripts/create_admin.py` — auth is
  PIN-based with an admin-only user-creation endpoint, so a fresh DB has no
  other way to create its first account.
- **CORS**: `Settings.cors_origins` (CSV env var, default `*` for dev) wired
  into `CORSMiddleware` in `app/main.py` — required for the Flutter web
  target to call the API from a browser.
- **`AppConfig.apiBaseUrl`** (Flutter) now actually reads
  `--dart-define=API_BASE_URL=...` (was silently hardcoded before — a real
  bug, not just a missing feature).
- **Android release signing**: `android/app/build.gradle.kts` reads a
  gitignored `android/key.properties` when present (see
  `android/key.properties.example`), falling back to debug signing when it
  doesn't — no keystore is checked into this repo.
- **CI**: `.github/workflows/ci.yml` runs backend pytest + `flutter
  analyze`/`flutter test` on push/PR to `main`.
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
- Login requires connectivity (backend is authority); session survives restarts offline.
- COP currency via `intl`; night tariff = time window that replaces day tariff.
- Hive codegen: single `@GenerateAdapters` file at `lib/app/di/hive_adapters.dart`.
- Home occupancy: `DashboardCubit` is provided at the go_router `ShellRoute` (not on the `/` route), so the check-in/check-out pages can refresh the "Vehículos dentro" count after a submission; a failed refresh keeps the last known count instead of blanking the card (provider `create` runs once, so the bloc survives in-shell navigation).

## Test counts

- Backend (`cd backend && uv run pytest`): 240 passed, 4 skipped.
- Flutter (`flutter test`): 442 passed. `flutter analyze`: 0 issues.

## Layer map (Flutter feature slice)

`domain/` (entities + ports) -> `application/` (cubits) -> `infrastructure/` (Dio + Hive adapters) -> `presentation/` (pages).

## Backend layout

`app/domain` (entities/ports) -> `app/application` (services) -> `app/infrastructure` (SQLAlchemy models/repos) -> `app/presentation` (routers/schemas/deps). Migrations in `backend/alembic/versions/` (0001..0012).
