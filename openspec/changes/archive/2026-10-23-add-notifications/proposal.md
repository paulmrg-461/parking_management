## Why

Operators and admins have no way to learn about events unless they are looking at
the screen: a check-in/check-out or a monthly pass about to expire is only visible
by refreshing the relevant page. The app needs an inbox with live updates and,
when Firebase is configured, background push delivery.

## What Changes

- New `notifications` and `device_tokens` tables with RLS: users read/mark only
  their own notifications; triggers create notifications for admins on
  check-in/check-out and for passes expiring in three days.
- Supabase Realtime publishes new notification rows to the signed-in app.
- Flutter notification center: bell with unread badge, `/notifications` inbox,
  mark one/all read, in-app banner on realtime inserts, Hive cache.
- Optional FCM: device-token RPCs, `push-dispatch` Edge Function (FCM HTTP v1,
  service-role protected) and a host cron script for pending delivery.
- No changes to the business RPCs; notifications are derived from existing rows.

## Impact

- **Database**: migration `0008_notifications.sql` (tables, RLS, RPCs, triggers,
  Realtime publication).
- **Edge Functions**: `push-dispatch`.
- **Flutter**: new `features/notifications` slice, shell bell/badge/route,
  `firebase_core`/`firebase_messaging` (FCM is opt-in via dart-defines).
- **Ops**: optional `FCM_SERVICE_ACCOUNT_JSON` and
  `supabase/notifications-cron.sh`; in-app notifications need no extra config.
