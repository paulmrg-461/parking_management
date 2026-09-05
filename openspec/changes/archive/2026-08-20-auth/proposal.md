## Why

Operators must be able to sign in before using the parking system, and their
permissions must differ by role (admin manages configuration; operators run
check-in/check-out). Without authentication there is no accountability for
entries, payments, or evidence, and no way to gate administrative actions.

## What Changes

- Add a `User` concept with a username, display name, role (`admin` | `operator`),
  and a hashed PIN (Argon2id).
- Add login (username + PIN) producing a persisted session (offline-first: the
  session survives app restarts and works without connectivity).
- Add logout and session restoration.
- Enforce roles so admin-only actions (user management) are rejected for operators.
- Add backend endpoints: `POST /auth/login`, `GET /users`, `POST /users`,
  `PATCH /users/{id}` with JWT auth and admin-only guards.
- Add a login screen and route guarding in the Flutter app.

## Capabilities

### New Capabilities

- `auth`: operator login with PIN, persisted offline-first session, logout, and
  role availability to the app.
- `user-management`: admin-only create/list/update/deactivate of users.

### Modified Capabilities

(none)

## Impact

- Backend: new `User` model + Alembic migration; `auth` and `users` routers;
  auth dependencies (`get_current_user`, `require_admin`); new schemas and a
  login/registration service in `application/`.
- Flutter: new `features/auth` feature (domain/application/infrastructure/
  presentation) + `features/users` (admin management); `AuthCubit`, `User`
  and `AuthSession` entities, `AuthRepository` port, remote (Dio) and local
  (Hive CE) adapters; login page; route guard in `app/router`.
- `openspec/specs/` gains `auth` and `user-management` after archive.
