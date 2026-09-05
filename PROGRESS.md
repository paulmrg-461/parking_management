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

## Remaining changes (planned order)

1. `check-in` (+ `evidence-capture`) — entry + damage photos
2. `billing` — hourly/day/night/monthly computation
3. `check-out` — close entry, payment, ticket
4. `monthly-passes` — subscriptions
5. `reports` — revenue, occupancy (web-first)
6. `offline-sync` — outbox push/pull

## Key technical decisions

- Local store: **Hive CE** (not Isar — Isar's generator is EOL/incompatible with modern source_gen).
- State: **flutter_bloc + Equatable** (not Freezed — Freezed stable pins analyzer <11, conflicting with modern DB generators).
- DI: **get_it manual registration** (not injectable — source_gen conflict with Isar/Hive).
- Offline-first: session persists in Hive; reads cached with network fallback; mutations remote-only for now.
- Login requires connectivity (backend is authority); session survives restarts offline.
- COP currency via `intl`; night tariff = time window that replaces day tariff.
- Hive codegen: single `@GenerateAdapters` file at `lib/app/di/hive_adapters.dart`.

## Test counts

- Backend (`cd backend && uv run pytest`): 41 passed.
- Flutter (`flutter test`): 67 passed. `flutter analyze`: 0 issues.

## Layer map (Flutter feature slice)

`domain/` (entities + ports) -> `application/` (cubits) -> `infrastructure/` (Dio + Hive adapters) -> `presentation/` (pages).

## Backend layout

`app/domain` (entities/ports) -> `app/application` (services) -> `app/infrastructure` (SQLAlchemy models/repos) -> `app/presentation` (routers/schemas/deps). Migrations in `backend/alembic/versions/` (0001..0004).
