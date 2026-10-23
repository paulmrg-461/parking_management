#!/bin/sh
# API-level end-to-end smoke against a running stack:
#   login → check-in → check-out → revenue report → vehicle history
#
#   SUPABASE_URL=http://localhost:8000 sh supabase/tests/e2e.sh
#
# Uses the default admin (admin/123456) unless E2E_USERNAME/E2E_PIN are set.
# Requires curl, python3 and a stack with the migrations applied.
set -eu

cd "$(dirname "$0")/../.."

getenv() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2-; }
api=${SUPABASE_URL:-$(getenv SUPABASE_PUBLIC_URL)}
api=${api:-http://localhost:8000}
anon=${SUPABASE_ANON_KEY:-$(getenv ANON_KEY)}
username=${E2E_USERNAME:-admin}
pin=${E2E_PIN:-123456}

if [ -z "$anon" ]; then
  echo "missing ANON_KEY (set SUPABASE_ANON_KEY or generate .env)" >&2
  exit 2
fi

json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

echo "== login $username"
token=$(curl -fsS -X POST "$api/auth/v1/token?grant_type=password" \
  -H "apikey: $anon" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$username@parking.local\",\"password\":\"$pin\"}" | json "d['access_token']")
auth="Authorization: Bearer $token"

echo "== lots"
lot=$(curl -fsS -X POST "$api/rest/v1/rpc/my_lots" \
  -H "$auth" -H "apikey: $anon" -H 'Content-Type: application/json' -d '{}' |
  json "min(l['id'] for l in d)")
[ -n "$lot" ] || { echo "user belongs to no lot" >&2; exit 1; }

echo "== category/tariff (lot $lot)"
category=$(curl -fsS "$api/rest/v1/categories?lot_id=eq.$lot&name=eq.car&select=id" \
  -H "$auth" -H "apikey: $anon" | json "d[0]['id']")
hourly=$(curl -fsS "$api/rest/v1/tariffs?category_id=eq.$category&type=eq.hourly&active=is.true&select=id" \
  -H "$auth" -H "apikey: $anon" | json "len(d)")
if [ "$hourly" = "0" ]; then
  curl -fsS -X POST "$api/rest/v1/tariffs" \
    -H "$auth" -H "apikey: $anon" -H 'Content-Type: application/json' \
    -H 'Prefer: return=minimal' \
    -d "{\"category_id\":$category,\"lot_id\":$lot,\"type\":\"hourly\",\"amount\":5000,\"active\":true}" >/dev/null
fi

plate="E2E$(date +%s | tail -c 7)"
echo "== check-in $plate"
session=$(curl -fsS -X POST "$api/rest/v1/rpc/check_in" \
  -H "$auth" -H "apikey: $anon" -H 'Content-Type: application/json' \
  -d "{\"p_plate\":\"$plate\",\"p_category_id\":$category,\"p_photos\":[],\"p_idempotency_key\":\"e2e-in-$plate\"}")
session_id=$(printf '%s' "$session" | json "d['id']")
[ "$(printf '%s' "$session" | json "d['status']")" = "open" ] || {
  echo "check-in did not open a session: $session" >&2; exit 1
}
[ "$(printf '%s' "$session" | json "d['lot_id']")" = "$lot" ] || {
  echo "check-in landed in the wrong lot: $session" >&2; exit 1
}

echo "== check-out"
receipt=$(curl -fsS -X POST "$api/rest/v1/rpc/check_out" \
  -H "$auth" -H "apikey: $anon" -H 'Content-Type: application/json' \
  -d "{\"p_session_id\":$session_id,\"p_payment_method\":\"cash\",\"p_idempotency_key\":\"e2e-out-$plate\"}")
amount=$(printf '%s' "$receipt" | json "d['amount_charged']")
ticket=$(printf '%s' "$receipt" | json "d['ticket_number']")
case "$ticket" in TCK-*) ;; *) echo "unexpected ticket: $ticket" >&2; exit 1 ;; esac

echo "== report"
today=$(date +%F)
report=$(curl -fsS -X POST "$api/rest/v1/rpc/report_revenue" \
  -H "$auth" -H "apikey: $anon" -H 'Content-Type: application/json' \
  -d "{\"p_start_date\":\"$today\",\"p_end_date\":\"$today\"}")
total=$(printf '%s' "$report" | json "d['total']")
[ "$total" -ge "$amount" ] || {
  echo "report total $total is below the charged amount $amount" >&2; exit 1
}

echo "== history"
visits=$(curl -fsS -X POST "$api/rest/v1/rpc/vehicle_history" \
  -H "$auth" -H "apikey: $anon" -H 'Content-Type: application/json' \
  -d "{\"p_plate\":\"$plate\"}" | json "d['visits']")
[ "$visits" -ge 1 ] || { echo "history is empty for $plate" >&2; exit 1; }

echo "e2e OK: plate=$plate amount=$amount ticket=$ticket total=$total visits=$visits"
