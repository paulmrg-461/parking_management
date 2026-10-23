# Parking Management

Offline-first parking management system: vehicle check-in/check-out, time-based
billing (hourly/daily/nightly rates, per-day caps), vehicle categories, monthly
passes, evidence photos, license-plate OCR scanning, and admin revenue/occupancy
reports.

- `supabase/` — self-hosted Supabase stack + SQL schema, RPCs, RLS, Storage
  buckets and the admin-users Edge Function (source of truth)
- `lib/` — Flutter app (Android + Web), Hive-backed offline cache + sync outbox
- `openspec/` — specs and change history (spec-driven development); see
  `PROGRESS.md` for the capability changelog

There is no application server: the client talks to Supabase Auth, PostgREST and
Storage directly, and business rules live in PostgreSQL functions.

## Architecture

```
Flutter (hexagonal, per feature)
  domain -> application -> infrastructure -> presentation
                                |
                 Supabase client (JWT, PostgREST, Storage, Functions)
                                |
        Envoy gateway :8000 -> GoTrue / PostgREST / Storage / Realtime
                                |
                      PostgreSQL 17 (public schema + RLS)
```

- **Auth**: GoTrue. The kiosk asks for username + 6-digit PIN; the client maps it
  to `<username>@parking.local` and the PIN as the password.
- **Reads/writes**: PostgREST with RLS. `anon` has no table grants.
- **Business logic**: `public.check_in`, `public.check_out`,
  `public.calculate_fare`, `public.report_revenue`, `public.report_occupancy`,
  `public.set_branding_logo` (security definer, operator derived from
  `auth.uid()`).
- **Users**: `admin-users` Edge Function (service-role stays server-side).
- **Photos/logo**: Supabase Storage (`evidence` private, `branding` public).
- **Offline**: Hive cache + outbox; replays the same RPCs and `client_ref`
  idempotency keys.

## Quickstart

```bash
cp .env.example .env
sh supabase/generate-env.sh     # generates DB/JWT/dashboard/API keys
docker compose up -d --build    # pulls Supabase, applies migrations

sh supabase/create-operator.sh admin 123456 admin
```

| What | Where |
|---|---|
| Supabase API gateway | http://localhost:8000 |
| Studio | http://localhost:8000 (basic auth `DASHBOARD_*`) |
| Auth | http://localhost:8000/auth/v1 |
| REST | http://localhost:8000/rest/v1 |
| Storage | http://localhost:8000/storage/v1 |
| Postgres (Supavisor) | `localhost:5432`, database `parking` |

Migrations in `supabase/migrations/` are applied once by the
`supabase-migrate` one-shot service and tracked in `public.schema_migrations`.
See `supabase/README.md` for operations, resets and security notes.

## Flutter

Requires the Flutter SDK (beta channel, see CI) and the running stack.

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY from .env>
```

- Android emulator: use `http://10.0.2.2:8000` (debug builds allow cleartext).
- Release builds must point at an HTTPS gateway; Android blocks cleartext by
  default, so terminate TLS in front of Envoy (Caddy/nginx) for production.
- Web: run `flutter run -d chrome --web-port 5000`; the gateway allows the
  origins configured by the stack (adjust `supabase/volumes/api/envoy` if you
  restrict them).
- Tests: `flutter test`. Static analysis: `flutter analyze`.

## Operators and roles

```bash
sh supabase/create-operator.sh juan 123456 operator
sh supabase/create-operator.sh admin 123456 admin
```

The `auth.users` trigger mirrors the profile into `public.users` and copies
`app_metadata.role`. PINs must be 6 digits (GoTrue minimum). Admins manage users
from the app; creation/role/active changes go through the `admin-users` Edge
Function.

## Notifications and push

**In-app (works out of the box):** PostgreSQL triggers create rows in
`public.notifications` for admin check-in/check-out events; monthly pass
expiry alerts come from `notify_expiring_monthly_passes()` and overstay alerts
from `notify_overstays()` (default 24 h, configurable in
`parking_settings.overstay_hours`). The Flutter app
subscribes to `public.notifications` through Supabase Realtime (RLS-scoped),
shows a bell with the unread count and an inbox at `/notifications`, and shows
a banner when a new row arrives.

**Background push (FCM):** Supabase does not deliver push itself. Set
`FCM_SERVICE_ACCOUNT_JSON` in `.env` (single-line Firebase service-account
JSON), restart the `functions` service, and schedule `supabase/notifications-cron.sh`
from host cron every minute. The `push-dispatch` Edge Function sends pending
notifications to FCM and is protected by the service-role key.

**Flutter (Android):** register the app in Firebase
(`pro.devpaul.parking_management`) and run with:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=FCM_ENABLED=true \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

The device token is registered automatically after login. Without
`FCM_ENABLED`/Firebase options the app still gets in-app notifications; web
push additionally needs `firebase-messaging-sw.js` and a VAPID key
(`FCM_VAPID_KEY`).

## Check-out, payments and history

Check-out asks for the payment method (cash, card, transfer, monthly pass or
exempt); monthly passes override the selection and charge zero. Revenue reports
break down income by payment method. The `/history` screen (also linked from
Home) looks up a plate and shows its visits, total spent, open-session flag and
the latest sessions, with an offline cache per plate.

## Billing rules

- Tariffs per category: hourly, daily, nightly, monthly (COP).
- Night tariff is a time window that replaces the day tariff during that window.
- Fractional hours ceil once per calendar day per rate type; daily cap applies
  independently to every day touched; monthly pass → 0.
- Billing day boundaries and night windows use
  `public.parking_settings.business_timezone` (default `America/Bogota`).

## OpenSpec workflow

New capabilities go through `openspec/changes/<name>/` before implementation;
`openspec archive` folds an approved change into `openspec/specs/`.
`PROGRESS.md` tracks the capability history and key technical decisions.

## License

MIT — see `LICENSE`.
