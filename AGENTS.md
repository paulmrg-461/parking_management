# Parking Management — Agent Conventions

## Overview

Parking management system (parqueadero): vehicle registration/control, time-based
billing, vehicle categories, night rates, damage evidence photos, and automatic
license plate detection.

Monorepo:
- `lib/` — Flutter app (targets: `android` + `web`)
- `supabase/` — self-hosted Supabase (Postgres schema, RPCs, RLS, Storage, Edge Functions) — source of truth
- `openspec/` — specs and changes (spec-driven development via OpenSpec)

## Architecture (MANDATORY)

Hexagonal (Ports & Adapters) + Clean Architecture, organized **by feature**.

```
lib/features/<feature>/
├── domain/           # entities + repository ports (abstract). Depends on nothing.
├── application/      # use cases + cubits (orchestration + state)
├── infrastructure/   # adapters (Supabase, Hive), models, mappers
└── presentation/     # pages, widgets
```

- Outer layers depend on inner layers; `domain/` depends on nothing.
- SOLID strictly. Clean Code: functions ≤ 20 lines, max 2 params, meaningful names.
- Patterns: Repository, UseCase, Adapter, Factory, DI Singleton (get_it), Observer (Cubit).

## Naming

ALL code, classes, variables, files, and comments MUST be in English.
OpenSpec artifacts (proposal, specs, design, tasks) MUST be in English.

## Stack

Flutter: BLoC/Cubit + Equatable, `get_it` (manual registration), Hive CE
(offline-first local store), `supabase_flutter`, `go_router`, `camera` +
`image_picker`, `google_mlkit_text_recognition`, `intl` (COP, no decimals).

Backend: self-hosted Supabase (PostgreSQL 17 + RLS, GoTrue, PostgREST,
Storage, Edge Functions) in `supabase/`. There is no application server: SQL
RPCs own business logic and the Flutter client calls Supabase directly.

## Current state (post-migration, 2026-10-23)

- Branch `feature/supabase`: FastAPI, Alembic, Dio, Redis and `backend/` are
  deleted. Do not reintroduce them.
- `docker compose up -d` from the repo root is the whole stack. Gateway/Studio
  are on `:8000`; schema is applied by `supabase-migrate`.
- Local admin: `sh supabase/create-operator.sh admin 123456 admin` (6-digit
  PIN; rotate outside a disposable dev DB).
- Flutter needs `--dart-define=SUPABASE_URL=...` and
  `--dart-define=SUPABASE_ANON_KEY=...`; `configureDependencies()` fails fast
  without them.
- Key files: `supabase/migrations/0001..0016` (schema/RLS/RPCs/constraints/
  notifications/payments/history/capacity/shifts/renewal/audit/pass charges), `supabase/volumes/functions/{admin-users,push-dispatch}`,
  `lib/app/di/injection.dart`, `lib/core/network/supabase_error_mapper.dart`.
- Payments: check-out requires a method; monthly passes force `monthly_pass`.
  Discounts are admin-only with a required reason; shifts reconcile cash by
  operator; categories may cap capacity; auto-renew passes create linked rows.
  Vehicle history is `rpc/vehicle_history`; overstay alerts use
  `parking_settings.overstay_hours`. A lost ticket charges the full daily tariff
  with a mandatory reason; blacklisted vehicles cannot check in; reservations
  (`category_reservations`) hold capacity until used, cancelled or expired.
- UX invariants: check-out search is server-side/paginated; the shift card and
  no-shift warning live in the shell-scoped `ShiftCubit`; discount audit detail
  is exposed only in the admin revenue report. Cash/shift actions (open, close,
  movement, adjust, pass collection) are disabled offline with a banner — they
  are never queued. Notification taps deep-link by type via
  `notification_routes.dart`.
- Printed receipts localize through `ReceiptLabels` (es/en); nothing may
  hardcode receipt labels.
- Multi-lot: every site-owned table carries `lot_id`; RLS and RPCs resolve the
  active lot with `current_lot_id()` (`x-lot-id` header validated against
  `lot_members`, lowest membership as fallback). Never trust a client lot id
  except through `resolve_lot()`. New site data must be stamped with the lot
  and filtered in reads; queued mutations capture `lot_id` at enqueue time.
- Notifications: in-app rows + Supabase Realtime work with no extra config;
  browser push uses `web/push-sw.js` + VAPID (`web_push_subscriptions`);
  `FCM_SERVICE_ACCOUNT_JSON` + `supabase/notifications-cron.sh` enable
  background FCM. `push-dispatch` is service-role-only; never expose the key.
- Tests: `flutter test` (472) + `flutter analyze`; CI validates compose and
  runs `supabase/tests/run.sh` (real migrations + RPC/RLS tests) against
  `supabase/postgres`.
- Backups: `sh supabase/backup.sh` (DB dump + Storage); restore with
  `RESTORE_CONFIRM=yes sh supabase/restore.sh <dir>`. `.env` is not included.
- Known operational notes: pre-migration data needs a manual `pg_dump`/restore;
  Android release requires HTTPS in front of Envoy; `idempotency_keys` has no
  automatic TTL purge yet.

## Business rules

- Categories: moto, car, camioneta, camion, bus (configurable).
- Tariffs per category: hourly, daily, nightly, monthly (COP).
- Night tariff is a time window that REPLACES the day tariff during that window.
- Billing: fractional hours ceil to next hour; daily cap; monthly pass → 0.
- Evidence photos (dents/scratches) at check-in.
- Offline-first: Hive CE local source of truth + outbox sync queue.
- Receipt/ticket internal only (no electronic invoicing).

## TDD

Write 3 tests (Success / Failure / Security) BEFORE logic.

## Implementation invariants (from the review hardening pass)

- **Retryable writes**: generate `client_ref` BEFORE the first attempt, send
  it as `Idempotency-Key`, and persist the SAME ref if the attempt is queued.
  Never create the key only inside the failure branch.
- **Offline timestamps**: capture `client_entry_time` / `client_exit_time`
  before the first request (not at replay) and validate them server-side with
  `MAX_CLIENT_CLOCK_SKEW`.
- **Sync lifecycle**: restore the session before `SyncService.start()`;
  `AuthCubit` flushes the outbox on login. 401 stops the drain (login
  resumes); 403 is a `ValidationFailure` and dead-letters only that entry.
- **Cubits**: extend `ResilientCubit` (never raw `Cubit`) so an in-flight
  future that resolves after `close()` cannot throw. Submission flows must
  catch non-`Failure` errors and always leave `SubmissionInProgress`.
- **Auth storage**: both the app JWT (`TokenStore`) and the Supabase SDK session
  (`SecureSupabaseStorage`) live in `flutter_secure_storage`; Hive only stores
  the profile. Logout clears reference-data caches and signs out locally
  (`SignOutScope.local`) but never clears the outbox. The auth-state listener
  refreshes the Hive token snapshot.
- **Lists used for lookups** (open sessions, vehicles, monthly passes) must
  walk every Supabase page; PostgREST caps rows per request.
- **UI text**: always `context.l10n`; no hardcoded operator-facing strings.
- **Supabase**: `supabase/migrations` is the only schema owner (applied by
  `supabase-migrate`). Every new table ships grants + RLS before PostgREST sees
  it; writes go through `security definer` RPCs that derive the operator from
  `auth.uid()` and enforce idempotency.
- **Auth**: GoTrue only. Usernames map to `<username>@parking.local` with a
  6-digit PIN as password; `public.users` is mirrored by the `auth.users`
  trigger. Never put the service-role key in the client — admin user changes go
  through the `admin-users` Edge Function.

## Spec-driven workflow (OpenSpec)

- Plan with OpenSpec: `openspec new change <name>` then fill proposal → specs → design → tasks.
- Implement via tasks; archive with `openspec archive <name>`.
- Before implementation, read `openspec/changes/<name>/` artifacts.
