## 1. Database

- [x] 1.1 `notifications` + `device_tokens` tables, indexes and RLS (own rows only)
- [x] 1.2 `mark_notifications_read`, `register_device_token`, `unregister_device_token` RPCs
- [x] 1.3 Check-in/check-out admin triggers with per-user dedupe keys
- [x] 1.4 Monthly-pass expiry alert function (idempotent)
- [x] 1.5 Add `notifications` to the `supabase_realtime` publication

## 2. Push bridge

- [x] 2.1 `push-dispatch` Edge Function (service-role protected, FCM HTTP v1)
- [x] 2.2 `FCM_SERVICE_ACCOUNT_JSON` wiring + no-op when unconfigured
- [x] 2.3 `supabase/notifications-cron.sh` (expiry + dispatch)

## 3. Flutter

- [x] 3.1 Notification entity/port, Supabase remote + Hive cache repository
- [x] 3.2 NotificationsCubit (load, realtime insert, unread count, mark read/all)
- [x] 3.3 Bell with badge, `/notifications` inbox, shell banner and nav destination
- [x] 3.4 Optional FCM registration via `firebase_messaging` + dart-defines
- [x] 3.5 Tests: cubit success/failure/security + page/bell widget tests
