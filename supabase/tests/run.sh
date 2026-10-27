#!/bin/sh
# Applies bootstrap + migrations + SQL regression tests against a fresh
# supabase/postgres database. Used by CI; requires psql in PATH.
set -eu

cd "$(dirname "$0")/.."
PSQL="psql -v ON_ERROR_STOP=1 -X"

echo "bootstrapping Supabase stubs..."
$PSQL -f tests/bootstrap.sql

echo "applying migrations..."
for file in migrations/*.sql; do
  echo "  $file"
  $PSQL -1 -f "$file"
done

echo "running SQL regression tests..."
$PSQL -f tests/rpc_test.sql

echo "SQL tests passed"
