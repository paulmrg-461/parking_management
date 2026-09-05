## Why

The parking management system needs a solid, testable baseline before any business
feature can be built. This change establishes the monorepo skeleton (Flutter app for
Android + Web, and the FastAPI + PostgreSQL backend) following Hexagonal Clean
Architecture so every subsequent feature lands on a consistent, SOLID foundation.

## What Changes

- Initialize the Flutter application targets (`android` + `web`) with the hexagonal,
  feature-based package structure (`core/`, `app/`, `features/`, `shared/`).
- Add the Flutter dependency set: BLoC/Cubit + Freezed, `get_it` + `injectable`,
  Isar, Dio, `go_router`, `intl`, `camera`, `image_picker`.
- Wire dependency injection (`get_it` + `injectable`), the router (`go_router`),
  theme, and a landing/home page as a running shell.
- Scaffold the FastAPI backend with the hexagonal layout
  (`core/`, `domain/`, `application/`, `infrastructure/`, `presentation/`).
- Configure SQLAlchemy 2.0 (async), Alembic migrations, and PostgreSQL connectivity.
- Add backend auth scaffolding (JWT + Argon2id) and a health endpoint.
- Add CI-friendly test harnesses for both Flutter (`flutter_test`) and backend
  (`pytest` + `httpx`).

## Capabilities

### New Capabilities

- `app-foundation`: the Flutter app SHALL build and run on Android and Web with the
  hexagonal feature structure, dependency injection, routing, and a base page.
- `backend-foundation`: the FastAPI service SHALL expose a health endpoint, an async
  PostgreSQL-backed persistence layer, Alembic migrations, and JWT auth scaffolding.

### Modified Capabilities

(none)

## Impact

- `pubspec.yaml`, `analysis_options.yaml`, `lib/` (app/core/shared/features layout).
- New `backend/` service (FastAPI, SQLAlchemy 2.0 async, Alembic, PostgreSQL).
- New dependencies: `flutter_bloc`, `freezed`/`freezed_annotation`, `get_it`,
  `injectable`, `isar`, `dio`, `go_router`, `intl`, `camera`, `image_picker`
  (Flutter); `fastapi`, `uvicorn`, `sqlalchemy`, `asyncpg`, `alembic`,
  `pydantic-settings`, `pyjwt`, `argon2-cffi`, `httpx`, `pytest` (Python).
- `openspec/specs/` will gain `app-foundation` and `backend-foundation` after archive.
