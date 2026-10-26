#!/bin/sh
# Quarterly secret hygiene check. Read-only: prints findings, exits 1 when
# something needs action.
#
#   sh supabase/check-secrets.sh
set -eu

cd "$(dirname "$0")/.."

warnings=0
failures=0
warn() { echo "WARN: $*"; warnings=$((warnings + 1)); }
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
getenv() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2-; }

[ -f .env ] || { echo "FAIL: .env is missing" >&2; exit 1; }

mode=$(stat -c '%a' .env 2>/dev/null || stat -f '%Lp' .env 2>/dev/null || echo '')
case "$mode" in
  600|400) ;;
  *) warn ".env permissions are $mode (expected 600: chmod 600 .env)" ;;
esac

if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  fail ".env is tracked by git: remove it and rotate every secret"
fi

for key in POSTGRES_PASSWORD JWT_SECRET ANON_KEY SERVICE_ROLE_KEY; do
  value=$(getenv "$key")
  if [ -z "$value" ]; then
    fail "$key is empty in .env"
    continue
  fi
  case "$value" in
    *change-me*|*your-*|postgres|supabase|this_password_is_insecure*)
      fail "$key still has a placeholder value" ;;
  esac
  if [ "${#value}" -lt 32 ]; then
    warn "$key is shorter than 32 characters"
  fi
done

[ "$(getenv DISABLE_SIGNUP)" = "true" ] || warn "DISABLE_SIGNUP is not true"
[ "$(getenv PASSWORD_MIN_LENGTH)" = "6" ] || warn "PASSWORD_MIN_LENGTH should be 6 (PIN length)"

printf 'secrets under rotation control: '
found=''
[ -n "$(getenv FCM_SERVICE_ACCOUNT_JSON)" ] && found="$found fcm"
[ -n "$(getenv VAPID_PRIVATE_KEY)" ] && found="$found vapid"
[ -n "$(getenv WHATSAPP_TOKEN)" ] && found="$found whatsapp"
echo "${found:-none}"

echo "== summary"
echo "failures: $failures, warnings: $warnings"
[ "$failures" -eq 0 ]
