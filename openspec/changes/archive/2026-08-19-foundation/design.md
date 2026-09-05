## Context

The repository currently contains a bare `flutter create` scaffold (`lib/main.dart`
and a default `test/widget_test.dart`) with no architecture, no backend, and no
spec-driven artifacts. This change establishes the baseline for the parking
management system: a Flutter app (Android + Web) and a FastAPI + PostgreSQL backend,
both organized by feature under Hexagonal (Ports & Adapters) + Clean Architecture.

## Goals / Non-Goals

**Goals:**
- Running Flutter shell on Android and Web with hexagonal feature layout, DI, router,
  theme, and a base page.
- Running FastAPI service with a health endpoint, async SQLAlchemy 2.0 + PostgreSQL,
  Alembic migrations, and JWT + Argon2id auth primitives.
- A test harness in both stacks (3 tests per unit: Success / Failure / Security).

**Non-Goals:**
- No business features yet (auth flows, categories, tariffs, check-in/out, plate
  scanning, sync) — those are separate changes.
- No real database schema beyond the migration/connection plumbing.
- No CI pipeline file beyond testability; deployment is out of scope.

## Decisions

- **Monorepo over two repos**: a single repo keeps `lib/` and `backend/` under one
  OpenSpec planning home, so a change can span both app and API in one vertical slice.
  Alternative: separate repos + OpenSpec stores — rejected for now due to overhead.
- **Feature-first hexagonal layout**: each feature owns `domain/`, `application/`,
  `infrastructure/`, `presentation/`. `domain/` depends on nothing; adapters implement
  ports. Alternative: layer-first (all domains together) — rejected because feature
  cohesion and independent delivery matter more here.
- **BLoC/Cubit + Freezed for state**: immutable, testable state with generated union
  types. Alternative: Riverpod — rejected to match the established stack convention.
- **get_it + injectable for DI**: compile-time-generated registrations with minimal
  boilerplate. Alternative: manual service locator — rejected (less safe refactors).
- **Isar for local persistence (offline-first)**: fast, schema-indexed local DB.
  Alternative: Hive/Drift — Isar chosen for query power + sync-friendly model.
- **Dio for remote, go_router for navigation, intl for COP formatting**.
- **FastAPI + SQLAlchemy 2.0 async + asyncpg**: async-first, typed, modern. Alembic for
  migrations. Argon2id for password hashing (PHC winner), PyJWT for tokens.
- **pydantic-settings** for typed config via environment variables (12-factor friendly).
- **English naming everywhere**, including OpenSpec artifacts.

## Risks / Trade-offs

- [Flutter beta SDK (`3.48.0-0.1.pre`) may drift] → pin resolution in `pubspec.lock`,
  keep `environment.sdk` matching, avoid bleeding-edge APIs.
- [Dual-target Android + Web needs conditional camera/ML code later] → isolate
  platform-specific adapters behind ports now; keep shared code pure.
- [asyncpg vs psycopg differences] → commit to `asyncpg` early and standardize the
  engine factory; document connection URL shape.
- [Hexagonal layering can over-split small features] → allow simple features to omit
  empty layers, but never break the dependency direction.
- [PostgreSQL may not be running locally during tests] → keep unit tests DB-agnostic;
  use a health/config smoke test, defer integration tests to a Docker/PG later change.

## Migration Plan

1. Scaffold Flutter app structure + dependencies (`flutter pub get`).
2. Scaffold backend structure + dependencies (venv + `pip install -e .`).
3. Verify: `flutter analyze` + `flutter test`; `pytest`; health endpoint smoke test.
4. No rollback needed (additive scaffolding); revert is a clean checkout.

## Open Questions

- None blocking. DB provisioning (local Postgres/Docker) will be detailed in the
  offline-sync change; for now the engine uses an env-provided URL with a safe default.
