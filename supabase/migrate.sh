#!/bin/sh
# Apply supabase/migrations/*.sql exactly once, in filename order.
# Runs as a one-shot compose service (supabase-migrate).
set -eu

PGHOST="${PGHOST:-db}"
PGUSER="${PGUSER:-postgres}"
PGDATABASE="${PGDATABASE:-parking}"
ADMIN_USER="${PGADMIN_USER:-supabase_admin}"
export PGHOST PGUSER PGDATABASE
export PGPASSWORD="${PGPASSWORD:-postgres}"

echo "waiting for postgres at ${PGHOST}/${PGDATABASE}..."
until pg_isready -q; do
  sleep 1
done

# Supabase ships the `public` schema with CREATE revoked from `postgres`.
# The app role owns the tables, so let it create them (the stack superuser
# runs this bootstrap once).
echo "granting schema privileges to ${PGUSER}..."
psql -U "$ADMIN_USER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 <<SQL
grant create, usage on schema public to ${PGUSER};
grant all on database ${PGDATABASE} to ${PGUSER};
SQL

psql -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists public.schema_migrations (
    name        text primary key,
    applied_at  timestamptz not null default now()
);
SQL

for file in /migrations/*.sql; do
  [ -e "$file" ] || continue
  name=$(basename "$file")
  applied=$(psql -tAc "select 1 from public.schema_migrations where name = '${name}'")
  if [ "${applied:-}" = "1" ]; then
    echo "skip ${name}"
    continue
  fi
  echo "apply ${name}"
  # -1: the migration and its bookkeeping row commit atomically.
  psql -1 -v ON_ERROR_STOP=1 -f "$file" \
    -c "insert into public.schema_migrations (name) values ('${name}')"
done

echo "migrations up to date"
