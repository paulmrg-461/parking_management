#!/bin/sh
# Creates a GoTrue user whose public.users profile is filled by the auth
# trigger. Usernames keep working as the kiosk's email local-part.
#
#   sh supabase/create-operator.sh <username> <pin> [admin|operator]
#
# Example:
#   sh supabase/create-operator.sh admin 123456 admin
set -eu

if [ $# -lt 2 ]; then
  echo "usage: $0 <username> <pin> [admin|operator]" >&2
  exit 2
fi

username=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._-')
pin=$2
role=${3:-operator}

case "$role" in
  admin|operator) ;;
  *) echo "role must be 'admin' or 'operator'" >&2; exit 2 ;;
esac

if [ -z "$username" ]; then
  echo "username is empty after normalization" >&2
  exit 2
fi
if [ "${#pin}" -lt 6 ]; then
  echo "PIN must have at least 6 digits (GoTrue minimum)" >&2
  exit 2
fi

cd "$(dirname "$0")/.."
getenv() { grep -E "^$1=" .env | head -1 | cut -d= -f2-; }

api=$(getenv SUPABASE_PUBLIC_URL)
service_key=$(getenv SERVICE_ROLE_KEY)
[ -n "$api" ] && [ -n "$service_key" ] || {
  echo "missing SUPABASE_PUBLIC_URL/SERVICE_ROLE_KEY in .env (run sh supabase/generate-env.sh)" >&2
  exit 1
}

curl -sS -X POST "$api/auth/v1/admin/users" \
  -H "apikey: $service_key" \
  -H "Authorization: Bearer $service_key" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${username}@parking.local\",\"password\":\"${pin}\",\"email_confirm\":true,\"app_metadata\":{\"role\":\"${role}\"}}"
echo
