## Why

The project runs a hand-written FastAPI + PostgreSQL backend: PIN auth, JWT issuance,
check-in/check-out transactions, idempotency and evidence-file storage all live in
application code. The operator wants self-hosted Supabase (Postgres + GoTrue +
PostgREST + Storage + Studio) in the repository's Docker Compose, with Supabase as
the backend instead of FastAPI.

This change starts that migration. It is deliberately phased: the full stack and
schema land first, Supabase Auth replaces PIN login next, then reads/writes move to
PostgREST/RPC and Storage, and finally FastAPI is removed once parity is proven.
Deleting FastAPI in one step would put billing, offline replay and evidence uploads
at risk without a second implementation to compare against.

## What Changes

- Vendor the official self-hosted Supabase stack under `supabase/` and include it
  from the root `docker-compose.yml` (Supabase API gateway on `:8001` while FastAPI
  keeps `:8000`).
- Move schema ownership to `supabase/migrations/*.sql`, applied by a one-shot
  `supabase-migrate` service; the backend skips Alembic when
  `SCHEMA_MANAGED_EXTERNALLY=1`.
- Add the Supabase auth link: `public.users.auth_user_id`, an `auth.users` trigger
  that mirrors profiles, helper functions and RLS policies for PostgREST.
- Accept GoTrue access tokens in FastAPI during the transition (HS256 `JWT_SECRET`,
  email local-part → username), while legacy PIN tokens keep working.
- Flutter: optional `SUPABASE_URL`/`SUPABASE_ANON_KEY` dart-defines; when present,
  login goes to Supabase Auth using `<username>@parking.local` + PIN (GoTrue
  password min length 6), and the cached bearer token is refreshed on auth events.
- Add storage buckets (`evidence`, `branding`) and their policies for the Storage
  phase.
- Not in this first slice: porting billing/check-in/check-out to SQL RPCs,
  removing FastAPI, moving local evidence uploads to Storage, and the admin user
  screens writing to GoTrue.

## Capabilities

### New Capabilities

- `supabase-platform`: running the self-hosted Supabase stack, owning the database
  schema, exposing RLS-protected PostgREST access, and hosting auth/storage.

### Modified Capabilities

- `auth`: operators can authenticate through Supabase Auth (GoTrue) while the
  transitional backend accepts both token kinds.
- `offline-sync`: eventually replays through Supabase RPCs instead of FastAPI
  endpoints; the outbox contract is unchanged.

## Impact

- **Infra**: new `supabase/` (compose, volumes, migrations, key/env generation,
  operator seed script), root `docker-compose.yml` rewritten around `include`,
  `supabase-migrate` one-shot service, backend entrypoint skips Alembic in
  Supabase mode.
- **Backend**: `core/config.py` (`SUPABASE_JWT_SECRET`), token issuers
  (`SupabaseTokenIssuer`, `CompositeTokenIssuer`), `deps.py` wiring; Alembic stays
  for local/CI until FastAPI is removed.
- **Flutter**: `supabase_flutter` dependency, `AppConfig` Supabase fields,
  `SupabaseAuthRemoteDataSource`, DI selection, token-refresh listener.
- **Database**: `public` tables consolidated in `0001`, auth/RLS in `0002`,
  buckets in `0003`, default categories in `0004`.
- **Docs/secrets**: `.env.example` merges app + Supabase variables;
  `supabase/generate-env.sh` generates the stack secrets locally.
- **Breaking**: fresh databases use the SQL migrations, not Alembic. Existing
  installations need a `pg_dump`/restore into the Supabase database.
