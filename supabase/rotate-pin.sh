#!/bin/sh
# Resets an operator's PIN. Host-side equivalent of the app's "Reset PIN",
# useful for the bootstrap admin or when nobody can sign in.
#
#   sh supabase/rotate-pin.sh <username> <new-6-digit-pin>
#
# It talks to the GoTrue admin API with the service key from `.env`, so it
# works even without a signed-in admin. The target user must already exist
# (see supabase/create-operator.sh).
set -eu

if [ $# -lt 2 ]; then
  echo "usage: $0 <username> <new-6-digit-pin>" >&2
  exit 2
fi

username=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._-')
pin=$2

case "$pin" in
  *[!0-9]*) echo "PIN must be digits only" >&2; exit 2 ;;
esac
if [ "${#pin}" -lt 6 ]; then
  echo "PIN must have at least 6 digits (GoTrue minimum)" >&2
  exit 2
fi
if [ -z "$username" ]; then
  echo "username is empty after normalization" >&2
  exit 2
fi

cd "$(dirname "$0")/.."
getenv() { grep -E "^$1=" .env | head -1 | cut -d= -f2-; }
api=$(getenv SUPABASE_PUBLIC_URL)
service_key=$(getenv SERVICE_ROLE_KEY)
[ -n "$api" ] && [ -n "$service_key" ] || {
  echo "missing SUPABASE_PUBLIC_URL/SERVICE_ROLE_KEY in .env" >&2
  exit 1
}

auth_id=$(curl -fsS "$api/rest/v1/users?username=eq.$username&select=auth_user_id" \
  -H "apikey: $service_key" -H "Authorization: Bearer $service_key" |
  python3 -c "import json,sys; rows=json.load(sys.stdin); print(rows[0]['auth_user_id'] if rows else '')")

[ -n "$auth_id" ] || { echo "user '$username' not found" >&2; exit 1; }

curl -fsS -X PUT "$api/auth/v1/admin/users/$auth_id" \
  -H "apikey: $service_key" \
  -H "Authorization: Bearer $service_key" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$pin\"}" >/dev/null

echo "PIN updated for '$username'."
echo "Sign in once with the new PIN and confirm /diagnostics reports no failures."
