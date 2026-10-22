#!/bin/sh
set -e

# In the self-hosted Supabase stack the schema is owned by
# supabase/migrations (applied by the supabase-migrate service). Locally and
# in CI, without Supabase, Alembic remains the schema owner.
if [ "${SCHEMA_MANAGED_EXTERNALLY:-0}" != "1" ]; then
  alembic upgrade head
fi

exec uvicorn app.main:app --host 0.0.0.0 --port 8000
