## 1. Backend domain and persistence

- [x] 1.1 Add `UserRole` enum and `User` domain model with PIN validation in `app/domain`
- [x] 1.2 Add SQLAlchemy `User` model and Alembic migration for the `users` table
- [x] 1.3 Add `UserRepository` port and SQLAlchemy implementation (get by username, create, list, update)
- [x] 1.4 Write 3 tests (Success / Failure / Security) for the user repository

## 2. Backend auth and user endpoints

- [x] 2.1 Add auth service (verify PIN + issue JWT) in `app/application`
- [x] 2.2 Add `POST /auth/login` endpoint returning a token and user
- [x] 2.3 Add `get_current_user` and `require_admin` dependencies
- [x] 2.4 Add `GET /users`, `POST /users`, `PATCH /users/{id}` admin endpoints
- [x] 2.5 Write 3 tests (Success / Failure / Security) for login and user management endpoints
- [x] 2.6 Run `pytest`; fix findings

## 3. Flutter domain and adapters

- [x] 3.1 Add `cryptography` dependency; add `UserRole`, `User`, and `AuthSession` entities
- [x] 3.2 Add `AuthRepository` port (login, logout, restoreSession, listUsers, createUser, updateUser)
- [x] 3.3 Add remote adapter (Dio) and local adapter (Hive CE) implementing `AuthRepository`
- [x] 3.4 Register adapters and repository in the DI container
- [x] 3.5 Write 3 tests (Success / Failure / Security) for the auth repository (local + remote)

## 4. Flutter presentation and state

- [x] 4.1 Add `AuthCubit` with Equatable states (initial/loading/authenticated/unauthenticated/failure)
- [x] 4.2 Add login page and wire it to `AuthCubit`
- [x] 4.3 Add route guard that redirects unauthenticated users to `/login`
- [x] 4.4 Write 3 tests (Success / Failure / Security) for `AuthCubit` and the login page
- [x] 4.5 Run `flutter analyze` and `flutter test`; fix findings

## 5. Verification

- [x] 5.1 Confirm `pytest` passes
- [x] 5.2 Confirm `flutter analyze` and `flutter test` pass
- [x] 5.3 Confirm `openspec validate auth` passes
