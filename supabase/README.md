# Self-hosted Supabase

Official self-hosted Supabase stack (Envoy gateway, Studio, GoTrue, PostgREST,
Realtime, Storage, imgproxy, postgres-meta, Edge Functions, Postgres,
Supavisor), vendored so the whole project runs from the repository root.

## Run it

```bash
cp .env.example .env          # once
sh supabase/generate-env.sh   # generates JWT/DB/dashboard secrets
docker compose up -d          # from the repo root
```

| What | Where |
|---|---|
| Studio | http://localhost:8001 (basic auth from `DASHBOARD_*`) |
| Auth (GoTrue) | http://localhost:8001/auth/v1 |
| REST (PostgREST) | http://localhost:8001/rest/v1 |
| Storage | http://localhost:8001/storage/v1 |
| Postgres | `localhost:5432`, database `parking` (Supavisor) |

FastAPI keeps `:8000` during the migration; the gateway moves to `:8000` when
FastAPI is removed.

## Migrations

`supabase/migrations/*.sql` are applied once, in filename order, by the
`supabase-migrate` one-shot service (`migrate.sh`). Applied files are recorded
in `public.schema_migrations`.

Add a migration by creating the next numbered file:

```bash
touch supabase/migrations/0005_my_change.sql
docker compose up supabase-migrate
```

The backend skips Alembic when `SCHEMA_MANAGED_EXTERNALLY=1` (set by the root
compose). Local/CI runs without Supabase still use Alembic.

## Auth and operators

GoTrue owns passwords; `public.users` is the app profile, kept in sync by an
`auth.users` trigger. Usernames map to `<username>@parking.local`.

```bash
sh supabase/create-operator.sh admin 123456 admin
sh supabase/create-operator.sh juan 123456 operator
```

- PINs must be **6 digits** (GoTrue clamps the minimum password length to 6).
- Signups are disabled; use the script or the GoTrue admin API.
- The legacy FastAPI PIN endpoint still works while the migration is in
  progress, but those users do not exist in GoTrue.

## Security notes

- `.env` and `volumes/db/data` are git-ignored. Never commit generated keys.
- `anon` has no table grants; all access goes through `authenticated` + RLS.
- Writes to sessions/evidence are intentionally denied until the billing RPCs
  land (FastAPI connects as the table owner meanwhile).
- Rotating `JWT_SECRET` invalidates all issued tokens AND the `ANON_KEY`/
  `SERVICE_ROLE_KEY` values; re-run `generate-env.sh` after changing it.

## Reset

```bash
docker compose down
rm -rf supabase/volumes/db/data supabase/volumes/storage
docker compose up -d
```

This deletes the database, uploads and all migrated data.

## Relation to the official stack

The compose file and `volumes/` come from `supabase/supabase` (`docker/`).
Local changes: project name inherited from the root compose, variables from the
root `.env`, gateway on `:8001`, database `parking`, and
`GOTRUE_PASSWORD_MIN_LENGTH=6`.
