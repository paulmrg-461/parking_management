#!/usr/bin/env sh
# Creates a kiosk user on a hosted Supabase project through the Admin API.
# Use the SECRET key (sb_secret_... or the service_role JWT), never the
# publishable key, and never ship it in the client.
#
#   sh supabase/create-cloud-operator.sh https://<ref>.supabase.co <secret-key> \
#       admin <6-digit-pin> admin
set -eu

if [ $# -lt 4 ]; then
  echo "usage: $0 <project-url> <secret-key> <username> <pin> [admin|operator]" >&2
  exit 2
fi

url=${1%/}
secret=$2
username=$(printf '%s' "$3" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._-')
pin=$4
role=${5:-operator}

case "$role" in
  admin|operator) ;;
  *) echo "role must be 'admin' or 'operator'" >&2; exit 2 ;;
esac
[ -n "$username" ] || { echo "username is empty after normalization" >&2; exit 2; }
[ "${#pin}" -ge 6 ] || { echo "PIN must have at least 6 digits" >&2; exit 2; }

# The auth trigger mirrors the profile into public.users and joins the default
# lot with the role from app_metadata.
curl -sS -X POST "$url/auth/v1/admin/users" \
  -H "apikey: $secret" \
  -H "Authorization: Bearer $secret" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${username}@parking.local\",\"password\":\"${pin}\",\"email_confirm\":true,\"app_metadata\":{\"role\":\"${role}\"}}"
echo
