## 1. Flutter shell

- [x] 1.1 Add dependencies to `pubspec.yaml` (flutter_bloc, freezed + freezed_annotation, get_it, injectable, injectable_generator, isar, isar_flutter_libs, dio, go_router, intl, camera, image_picker) and dev deps (build_runner, json_serializable, freezed)
- [x] 1.2 Create `lib/core/` layout: `config/`, `theme/`, `error/`, `network/`, `storage/`, `utils/`
- [x] 1.3 Create `lib/app/` with DI container (`get_it` + injectable setup), `app.dart`, and `router.dart` (go_router)
- [x] 1.4 Implement `theme` (Material 3) and a base home page rendering the root route
- [x] 1.5 Implement COP currency formatter utility in `core/utils` using `intl`
- [x] 1.6 Replace `lib/main.dart` to bootstrap DI, theme, and router; enable `web` and `android` targets
- [x] 1.7 Write 3 tests (Success / Failure / Security) for the currency formatter and a router smoke test
- [x] 1.8 Run `flutter analyze` and `flutter test`; fix findings

## 2. Backend shell

- [x] 2.1 Create `backend/` with `pyproject.toml` and dependencies (fastapi, uvicorn, sqlalchemy, asyncpg, alembic, pydantic-settings, pyjwt, argon2-cffi, httpx, pytest)
- [x] 2.2 Create `app/core/` (config via pydantic-settings, exceptions, security: Argon2id + JWT)
- [x] 2.3 Create `app/infrastructure/` (async SQLAlchemy engine + session factory, base model)
- [x] 2.4 Create `app/presentation/` (health router, app factory, main entrypoint)
- [x] 2.5 Configure Alembic with async engine (`env.py`, `alembic.ini`)
- [x] 2.6 Write 3 tests (Success / Failure / Security) for health endpoint and security primitives
- [x] 2.7 Run `pytest`; fix findings

## 3. Verification

- [x] 3.1 Confirm `flutter analyze` and `flutter test` pass
- [x] 3.2 Confirm `pytest` passes
- [x] 3.3 Confirm `openspec validate foundation` passes
