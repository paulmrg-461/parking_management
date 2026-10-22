## 1. Self-hosted Supabase stack

- [x] 1.1 Vendor the official self-hosted stack under `supabase/` (compose, volumes, utils) and include it from the root `docker-compose.yml`
- [x] 1.2 Remove the old `db` service; point FastAPI at Supabase Postgres (`db:5432/parking`) and keep Supabase's gateway on `:8001`
- [x] 1.3 Configure Auth for kiosk PINs (`PASSWORD_MIN_LENGTH=6`, email autoconfirm, signup disabled)
- [x] 1.4 Add `supabase/generate-env.sh` (secrets + HS256 anon/service keys) and merge app + Supabase variables into `.env.example`
- [x] 1.5 Validate `docker compose config` with zero missing-variable warnings
- [x] 1.6 Boot the full stack and verify Studio, `/auth/v1/health`, `/rest/v1/` and `/storage/v1/` respond

## 2. Schema ownership

- [x] 2.1 Consolidate the Alembic schema into `supabase/migrations/0001_core_schema.sql` (tables, indexes, partial unique indexes, settings singleton)
- [x] 2.2 Add `supabase/migrate.sh` + one-shot `supabase-migrate` service with `schema_migrations` bookkeeping
- [x] 2.3 Skip Alembic in Supabase mode (`SCHEMA_MANAGED_EXTERNALLY=1`) while keeping it for local/CI
- [x] 2.4 Seed the default categories (`0004_seed_reference_data.sql`)
- [ ] 2.5 Verify FastAPI's full test suite against the Supabase/Postgres 17 schema (currently Alembic/SQLite + plain Postgres in CI)

## 3. Supabase Auth

- [x] 3.1 Add `auth_user_id` to `public.users`, make `pin_hash` nullable, add the `auth.users` mirror trigger
- [x] 3.2 Map usernames to `<username>@parking.local`; GoTrue password min length 6 (it clamps lower values)
- [x] 3.3 Accept Supabase HS256 tokens in FastAPI (`SupabaseTokenIssuer` + `CompositeTokenIssuer`, `aud=authenticated`, email → username)
- [x] 3.4 Flutter: optional `SUPABASE_URL`/`SUPABASE_ANON_KEY` dart-defines and `SupabaseAuthRemoteDataSource`
- [x] 3.5 Refresh the cached Hive token on `onAuthStateChange`
- [x] 3.6 Add `supabase/create-operator.sh` to seed GoTrue users with a role
- [ ] 3.7 Move the admin user screen to GoTrue (create/patch/reset) or explicitly make it read-only in Supabase mode
- [ ] 3.8 Add an integration test: seeded operator logs in through GoTrue and calls a FastAPI endpoint

## 4. RLS and PostgREST reads

- [x] 4.1 Revoke `anon`, grant table/sequence access to `authenticated`, enable RLS on all app tables
- [x] 4.2 Policies: own profile/admin, reference-data reads, admin writes, operator vehicle insert
- [x] 4.3 Helper functions `current_app_role()` / `is_admin()` (security definer, no recursive RLS)
- [ ] 4.4 Move read-only Flutter repositories (categories, tariffs, vehicles, monthly passes, reports, settings) to the Supabase client
- [ ] 4.5 SQL tests proving anon gets nothing, operator cannot escalate, admin can write reference data

## 5. Writes and offline parity

- [ ] 5.1 Port fare calculation to a SQL function with the same golden cases as `FareCalculator`
- [ ] 5.2 `check_in` / `check_out` security-definer RPCs with idempotency keys and clock-skew validation
- [ ] 5.3 Point the outbox replayers at the RPCs; keep `client_ref` / client timestamps unchanged
- [ ] 5.4 Port monthly passes and reports
- [ ] 5.5 Re-run the offline check-in/check-out tests against Supabase

## 6. Storage and cutover

- [x] 6.1 Create `evidence` (private) and `branding` (public) buckets + policies
- [ ] 6.2 Upload evidence photos to Storage and store the object path
- [ ] 6.3 Move logo storage to the `branding` bucket
- [ ] 6.4 Remove FastAPI, Alembic, the Dio API layer and the local storage volumes; move the gateway to `:8000`
