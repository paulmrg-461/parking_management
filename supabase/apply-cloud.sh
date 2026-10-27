#!/usr/bin/env sh
# Applies supabase/migrations/*.sql to a hosted PostgreSQL (Supabase Cloud).
# Use the SESSION connection string (port 5432) with the database password.
# The URL is secret: pass it as an argument or DATABASE_URL, never commit it.
#
#   sh supabase/apply-cloud.sh "postgresql://postgres:PASS@db.<ref>.supabase.co:5432/postgres?sslmode=require"
#
# Uses the local psql when available, otherwise a throwaway postgres:17-alpine
# container (no client install needed).
set -eu

db_url=${1:-${DATABASE_URL:-}}
[ -n "$db_url" ] || { echo "usage: $0 <postgres-url>" >&2; exit 2; }

cd "$(dirname "$0")"
if command -v psql >/dev/null 2>&1; then
  run() { psql "$db_url" -v ON_ERROR_STOP=1 -q -f "$1"; }
else
  run() {
    docker run --rm -i -v "$PWD:/work" -w /work postgres:17-alpine \
      psql "$db_url" -v ON_ERROR_STOP=1 -q -f "$1"
  }
fi

for file in migrations/*.sql; do
  printf '== %s\n' "$file"
  run "$file" || {
    echo "failed applying $file" >&2
    exit 1
  }
done
echo "migrations applied"
