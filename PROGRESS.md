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

## Remaining changes (planned order)

1. `reports` — revenue, occupancy (web-first)
2. `offline-sync` — outbox push/pull

## Key technical decisions

- Local store: **Hive CE** (not Isar — Isar's generator is EOL/incompatible with modern source_gen).
- State: **flutter_bloc + Equatable** (not Freezed — Freezed stable pins analyzer <11, conflicting with modern DB generators).
- DI: **get_it manual registration** (not injectable — source_gen conflict with Isar/Hive).
- Offline-first: session persists in Hive; reads cached with network fallback; mutations remote-only for now.
- Login requires connectivity (backend is authority); session survives restarts offline.
- COP currency via `intl`; night tariff = time window that replaces day tariff.
- Hive codegen: single `@GenerateAdapters` file at `lib/app/di/hive_adapters.dart`.

## Test counts

- Backend (`cd backend && uv run pytest`): 89 passed.
- Flutter (`flutter test`): 89 passed. `flutter analyze`: 0 issues.

## Layer map (Flutter feature slice)

`domain/` (entities + ports) -> `application/` (cubits) -> `infrastructure/` (Dio + Hive adapters) -> `presentation/` (pages).

## Backend layout

`app/domain` (entities/ports) -> `app/application` (services) -> `app/infrastructure` (SQLAlchemy models/repos) -> `app/presentation` (routers/schemas/deps). Migrations in `backend/alembic/versions/` (0001..0008).
