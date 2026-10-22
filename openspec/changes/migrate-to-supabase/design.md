## Context

The backend is hexagonal FastAPI + PostgreSQL. PostgreSQL already stores every
domain table; Supabase's value is Auth (GoTrue), PostgREST, Storage and Studio on
top of the same database. The Flutter client is offline-first (Hive + outbox) and
talks to FastAPI through Dio today.

Constraints:

- Billing rules are covered by ~250 backend tests and must not be reimplemented
  twice in a way that can drift. The SQL/RPC port needs the same golden cases.
- Operators use a numeric keypad (numeric PIN) on a shared kiosk.
- Check-in/check-out and evidence uploads must keep working through the
  transition; dead-lettering or double charging is worse than a delayed migration.

## Goals / Non-Goals

**Goals**

- Reproducible self-hosted Supabase stack in `docker compose` with generated
  secrets.
- One schema owner (`supabase/migrations`) for fresh installs.
- Supabase Auth usable by the Flutter app without changing the kiosk UX.
- RLS enabled before PostgREST is exposed, so the anon key cannot read data.
- Phased path to delete FastAPI without a flag day.

**Non-Goals (this slice)**

- Reimplementing `FareCalculator`, check-in/check-out transactions or reports in
  SQL.
- Removing FastAPI.
- Migrating existing production rows (a dump/restore procedure is documented
  only).
- Supabase Realtime/Edge Functions for app logic.

## Decisions

### 1. Supabase as an included compose project

`supabase/docker-compose.yml` is the unmodified official stack (Envoy gateway,
Studio, Auth, REST, Realtime, Storage, imgproxy, meta, functions, db, Supavisor).
The root compose uses `include:`; the root `.env` is the single variable source.
The project name comes from the root directory, so containers stay grouped.

Ports: Supabase gateway `8001`, FastAPI `8000`, Postgres/Supavisor `5432`.
Supabase takes `8000` once FastAPI is removed.

### 2. SQL migrations own the schema

`supabase/migrations` contains the consolidated schema + RLS + seeds.
`supabase-migrate` (one-shot `postgres:17-alpine`) applies each file once and
records it in `public.schema_migrations`; each file and its bookkeeping row commit
in one transaction. The backend entrypoint runs Alembic only when
`SCHEMA_MANAGED_EXTERNALLY != 1`, so local/CI workflows are unchanged.

Alternative: keep Alembic forever and add Supabase SQL on top. Rejected because
the target has no FastAPI to run Alembic.

### 3. Auth: GoTrue owns credentials, `public.users` is the profile

- Username stays the UI identifier. GoTrue email is
  `<username>@parking.local`; the PIN is the password (GoTrue
  `PASSWORD_MIN_LENGTH=6`).
- An `auth.users` trigger upserts `public.users` by `auth_user_id` (or by
  username for legacy rows), copying `app_metadata.role` (`admin`/`operator`).
- FastAPI validates Supabase tokens with the shared HS256 `JWT_SECRET`
  (`aud=authenticated`) and maps the email local-part to the profile username.
  `CompositeTokenIssuer` tries legacy first, then Supabase.
- Flutter subscribes to `onAuthStateChange` and rewrites the cached Hive token
  when Supabase refreshes it; FastAPI's `AuthInterceptor` keeps reading Hive.

Why not email/password UI: the kiosk has no email and operators type PINs. The
mapping keeps the UX and the existing route guard.

### 4. RLS now, writes later

PostgREST is exposed by the stack, so `anon` is revoked and `authenticated` only
gets the rows RLS allows. Reads are open to signed-in users; session/evidence
writes have no policy until the check-in/check-out RPCs exist (FastAPI connects
as the owner and bypasses RLS during the transition). Admin writes are allowed
for reference data and settings.

### 5. Offline outbox contract is unchanged

The outbox keeps `client_ref` as `Idempotency-Key` and keeps entry/exit times
captured before the first attempt. When writes move to PostgREST/RPC, the same
payloads map to `security definer` functions that enforce billing and record the
idempotency key server-side. No client-side fare math.

## Risks / Trade-offs

- **RLS mistakes**: a missing policy either blocks operators or leaks revenue
  data. Mitigation: anon revoked, policies covered by SQL tests in phase 2.
- **Dual auth**: user creation through the old admin screen writes only
  `public.users`, not GoTrue. Mitigation: in Supabase mode, operators are created
  with `supabase/create-operator.sh`; the users UI migration is a phase 2 task.
- **Token refresh**: covered by the auth-state listener, but a cold start while
  offline still uses the last cached token until it expires.
- **Postgres 17 + Supabase image**: extensions and the `auth`/`storage` schemas
  differ from plain `postgres:16`. Mitigation: SQL migrations use only standard
  DDL; CI keeps testing Alembic against plain Postgres until removal.
- **Existing data**: no automated dump/restore in this slice; documented manual
  procedure.

## Migration Plan

1. **Phase 1 (this slice)**: stack, schema, RLS, buckets, dual token validation,
   Supabase Auth adapter in Flutter, operator seed script.
2. **Phase 2**: move read-only features (categories, tariffs, vehicles, passes,
   reports, settings) to the Supabase client; SQL tests for RLS.
3. **Phase 3**: port check-in/check-out/billing to `security definer` RPCs with
   idempotency; point the outbox at them; retire FastAPI write routes.
4. **Phase 4**: evidence/logo uploads to Storage; drop the local volumes.
5. **Phase 5**: delete FastAPI, Alembic and the Dio API layer; move the gateway
   to `:8000`.

Rollback: stop the Supabase services and run the old compose/backend against the
previous Postgres volume; auth falls back to PIN because `SUPABASE_API_URL` /
`SUPABASE_ANON_KEY` are empty.

## Open Questions

- Keep the legacy PIN endpoint after phase 3, or force a GoTrue migration for all
  users?
- Reports: PostgREST views vs `security definer` functions?
- Storage paths per session (`evidence/<session_id>/...`) and their policy
  granularity.
