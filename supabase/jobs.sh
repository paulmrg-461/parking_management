#!/bin/sh
# Retention and scheduled notifications for the self-hosted stack.
#
# Runs inside the compose network on a loop: the stock Postgres image has no
# pg_cron and a desktop/VM may not run a cron daemon, so the documented host
# cron (`supabase/notifications-cron.sh`) is not always available. Every task
# below is idempotent (dedupe keys, status filters), so an extra run at boot,
# an overlap with that script or with pg_cron is harmless.
#
#   JOBS_INTERVAL_SECONDS  seconds between runs (default 300)
#   API_URL                gateway seen from the container (default the stack)
#   SERVICE_ROLE_KEY       needed only for the push/WhatsApp dispatch
set -u

INTERVAL=${JOBS_INTERVAL_SECONDS:-300}
API_URL=${API_URL:-http://api-gw:8000}

run() {
  psql -v ON_ERROR_STOP=1 -tAc "select public.$1();" >/dev/null ||
    echo "jobs: $1 failed" >&2
}

dispatch() {
  if [ -z "${SERVICE_ROLE_KEY:-}" ]; then
    return 0
  fi
  wget -q -O /dev/null --timeout=20 \
    --header="Authorization: Bearer ${SERVICE_ROLE_KEY}" \
    --post-data="" "$1" ||
    echo "jobs: $1 failed" >&2
}

while true; do
  # Alerts for passes and overstays, pass renewals, and the retention jobs.
  run notify_expiring_monthly_passes
  run notify_overstays
  run notify_expiring_reservations
  # Cash anomaly rules over the last window; idempotent per subject.
  run detect_cash_anomalies
  run renew_monthly_passes
  run expire_reservations
  # Waitlist: reconcile/expire offers, then serve the queue (and the trigger
  # kicks a freed space left behind), and purge old terminal turns.
  run waitlist_expire
  run waitlist_dispatch_all
  run purge_waitlist
  # Rebuilds the occupancy profile when it is older than six hours.
  run refresh_occupancy_profile
  run purge_expired_idempotency
  run purge_stale_notifications
  run purge_client_error_reports
  run purge_audit_log
  run purge_whatsapp_messages
  # Shared AI usage log retention (floor 30 days).
  run purge_ai_requests
  run purge_cash_anomalies
  # Pass renewal reminders (queued only when the lot opted in).
  run queue_pass_renewal_reminders
  # Online payments: pending -> expired, then ask the gateway for anything the
  # webhook may have missed (both are no-ops without WOMPI_* credentials).
  run expire_payment_intents
  dispatch "${API_URL}/functions/v1/payments-reconcile"
  # Loyalty rewards past their validity become `expired`.
  run loyalty_expire_rewards
  # Electronic invoicing: default POS documents in `always` mode and the
  # dispatcher (a no-op without FISCAL_PROVIDER_* credentials).
  run enqueue_pending_fiscal_documents
  dispatch "${API_URL}/functions/v1/fiscal-dispatch"
  # Both are no-ops until their credentials are configured.
  dispatch "${API_URL}/functions/v1/push-dispatch"
  dispatch "${API_URL}/functions/v1/whatsapp-dispatch"
  sleep "$INTERVAL"
done
