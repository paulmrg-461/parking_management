## Context

Supabase self-hosted has no push provider. Realtime delivers rows to connected
apps; FCM/APNs are required for background delivery. The kiosk is normally open,
so in-app notifications cover the primary workflow, while push is opt-in.

## Decisions

1. **Notification rows are server-authored.** Triggers insert one row per admin
   with a dedupe key (`check_in:<id>:user:<id>`), so retries/replays never
   duplicate. Users cannot insert or edit rows; they only select their own and
   call `mark_notifications_read`.
2. **Realtime with RLS.** The `notifications` table is added to the
   `supabase_realtime` publication; RLS policies apply (`realtime.apply_rls`).
   The client also filters by `user_id=eq.<id>`.
3. **Push is a bridge, not a Supabase feature.** `push-dispatch` validates the
   service-role bearer, builds an FCM v1 OAuth token from the service account,
   sends notification+data payloads, and marks `pushed_at`/`push_attempts`.
   Without FCM credentials it is a no-op.
4. **Flutter is resilient.** The inbox is cached in Hive; Realtime errors are
   ignored (SDK reconnects); FCM init failures never block login. FCM token
   registration happens after authentication and on token refresh.
5. **Expiry alerts are idempotent** and intended to be called by a host cron
   (`notifications-cron.sh`) because pg_cron scheduling across databases adds
   operational complexity.

## Risks

- Realtime/RLS misconfiguration could leak notifications: the policy and the
  server-side filter restrict rows to `current_app_user_id()`.
- FCM credentials and Android Firebase configuration are external; the app
  works in-app without them.
- The push dispatcher retries up to three times; invalid tokens are deleted.
