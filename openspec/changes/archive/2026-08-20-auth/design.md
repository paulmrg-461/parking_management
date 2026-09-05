## Context

The foundation change established the monorepo (Flutter app + FastAPI backend),
dependency injection, routing, Hive CE storage, and backend security primitives
(Argon2id + JWT). This change adds the first business capability: authentication
and user management, in a hexagonal vertical slice across both app and API.

## Goals / Non-Goals

**Goals:**
- Login by username + PIN, producing a persisted, offline-first session with a role.
- Logout and session restoration.
- Backend auth endpoints (JWT) and admin-only user management (CRUD).
- A login screen and route guard; roles gating admin UI.

**Non-Goals:**
- Password reset / recovery flows.
- Refresh tokens or token revocation lists.
- Full user CRUD UI polish (a minimal admin list/create screen is enough).
- Sync of users to other devices (deferred to the offline-sync change).

## Decisions

- **Credentials: username + numeric PIN (4–6 digits)** over username + password:
  fast to enter at a kiosk-style booth, still unique per operator.
  Alternative: password — rejected (slower, unnecessary for booth operators).
- **Roles as a simple enum (`admin` | `operator`)** over a permission matrix:
  two roles cover current needs; a matrix is over-engineering now.
- **Backend hashes PIN with Argon2id** (argon2-cffi), consistent with the
  foundation security module. Alternative: bcrypt — rejected (Argon2id is the
  stronger PHC recommendation and already in place).
- **Offline-first session**: login requires connectivity (the backend is the
  authority), but the resulting session (user + token + role) is persisted in Hive CE
  so the operator stays signed in across restarts and while offline. A fresh login
  while offline is out of scope.
  Alternative: online-only auth with in-memory session — rejected (re-login on every
  launch); full offline login fallback — deferred to the sync change.
- **Session persisted in Hive CE** (current user + token + role); the app restores
  it on launch. Alternative: keep session only in memory — rejected (re-login on
  every launch).
- **JWT** (HS256, short-lived, `sub` = username, `role` claim) for backend auth,
  matching the foundation security module.
- **AuthCubit with Equatable states** (initial/loading/authenticated/unauthenticated/
  failure); route guard redirects to `/login` when unauthenticated.

## Risks / Trade-offs

- [Login requires connectivity] → acceptable; the session persists so day-to-day use
  works offline once signed in.
- [JWT `secret_key` default is insecure] → require `SECRET_KEY` in production via
  env; keep a safe default only for local dev.
- [Argon2id is CPU-expensive and could be DoS'd on login] → PIN length validated;
  future rate limiting noted as a follow-up.

## Migration Plan

1. Add the `users` table via Alembic migration (no seed; first admin created via
   `POST /users` by a bootstrap path or CLI later).
2. Ship backend + app together; no destructive change (additive).
3. Rollback: drop the migration and revert; no data migration required.

## Open Questions

- None blocking. Bootstrap admin creation will be addressed in the sync/setup change.
