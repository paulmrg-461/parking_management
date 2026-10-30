# Production readiness

The checklist the team uses before calling a build production-ready, and the
guards already implemented in the repo. Keep it current when a flow or an
operational assumption changes.

## 1. Service targets

| Concern | Target | How it is met |
|---|---|---|
| Availability | 99.9 % monthly (single region) | Docker Compose stack, healthchecks, restart policies, healthcheck script |
| Check-in / check-out p95 | < 400 ms server time | SQL RPCs only (no app server), lot-scoped indexes, server-side pagination |
| Data loss (RPO) | ≤ 24 h (or last manual backup) | `supabase/backup.sh`, offsite copy, restore drill |
| Recovery (RTO) | ≤ 60 min | `docs/runbook-restore.md` + `restore.sh` |
| Offline tolerance | Operator keeps working | Hive cache + outbox with idempotent replay |
| Evidence retention | Configurable, default forever | `evidence_retention_days` + `evidence-archive` |

## 2. Infrastructure

- [x] Only `443` public; `8000/5432/6543` bound to loopback (see
      `docs/infrastructure.md`). Android release requires HTTPS in front of
      Envoy.
- [x] Separate `.env` (`chmod 600`), generated secrets, quarterly rotation
      (`supabase/check-secrets.sh`, `docs/runbook-secrets.md`).
- [x] Recommended shape and sizing in `docs/deployment-requirements.md`
      (2 vCPU/4 GB minimum, 4/8/80–160 recommended, disk formula for evidence).
- [x] Postgres pooler enabled for many app clients; PostgREST and Realtime
      behind the gateway.
- [x] Nightly `pg_dump` + Storage/evidence copy; the dump is validated with
      `pg_restore --list`, `SHA256SUMS` is written next to the archive and
      `restore-drill.sh` runs against a scratch database in CI.
- [x] Host cron (or `pg_cron` when available) runs the retention jobs:
      idempotency keys (15 min), notifications (daily), reservations (hourly),
      evidence archive (daily).

## 3. Data and schema

- [x] `supabase/migrations` is the only schema owner; CI applies every
      migration on a real `supabase/postgres` image.
- [x] RLS on every site-owned table; RPCs are `security definer` and derive the
      operator from `auth.uid()`, the lot from `x-lot-id` → `current_lot_id()`.
- [x] Idempotent retries: `Idempotency-Key` stored before responding,
      `purge_expired_idempotency()` keeps the table bounded.
- [x] Open-session invariants: one open session per vehicle, one per bay, one
      open shift per operator/lot; partial unique indexes.
- [x] Scale guards (`0069`): trigram plate search (`pg_trgm` + GIN), lot/entry,
      pass/lot/end, reservation/lot/until and notification/lot/user indexes;
      `analyze` after creation.
- [x] Invariants: pass `end_date >= start_date`, non-negative pass amounts and
      charged amounts.
- [x] Every public table must have RLS: `rpc_test.sql` fails if a new table
      ships without it, and `0070` locks the runner's `public.schema_migrations`
      (RLS on, no grants for `anon`/`authenticated`).
- [x] Lists paginate server-side (`session_records`, vehicles, passes,
      notifications, audit); bounded page sizes (≤ 200).
- [ ] PITR/WAL archiving depends on the hosting choice; enable it on managed
      Postgres (documented limitation for self-hosted).

## 4. Security

- [x] GoTrue only; usernames map to `<user>@parking.local`, 6-digit PIN;
      `public.users` mirrored by the `auth.users` trigger.
- [x] Service-role key never ships in the client: admin user changes go through
      the `admin-users` Edge Function; `push-dispatch`/`whatsapp-dispatch` and
      `evidence-archive` are service-role only.
- [x] Evidence bucket policy uses `can_read_evidence()` (membership) because
      Storage/Realtime cannot see `x-lot-id`; public evidence requires the
      session + plate through the `public-evidence` function.
- [x] PIN rotation (`rotate-pin.sh`), last-admin/self-delete guards, audited
      user changes.
- [x] Audit trail covers reference data (actor, changed columns only, secrets
      dropped).
- [x] Admin-only discounts with a required reason; cash actions disabled
      offline and never queued.
- [x] Public static host (`parking-evidence-web`) sends `X-Content-Type-Options`,
      `Referrer-Policy`, `X-Frame-Options`, `Permissions-Policy` and gzip; the
      evidence links are plate-keyed and expire.
- [ ] Put a WAF/rate limit in front of GoTrue and PostgREST if the instance is
      public (host-level; `docs/deployment-requirements.md`).

## 5. Resilience

- [x] Offline-first: Hive local cache + outbox; queued writes keep their
      `client_ref` and client timestamps (validated with
      `MAX_CLIENT_CLOCK_SKEW`).
- [x] Sync lifecycle: session restored before `SyncService.start()`; 401 stops
      the drain, 403 dead-letters only that entry; `AuthCubit` flushes on login.
- [x] `ResilientCubit` everywhere; submissions always leave
      `SubmissionInProgress`; expected `Failure`s are not reported as crashes.
- [x] Friendly route fallback (`RouteErrorPage`) for unknown/deep-link paths.
- [x] Server unreachable: localized error + retry on every list; offline banner
      in the shell; realtime falls back to refresh on focus.
- [x] Scheduled jobs never call `current_lot_id()`; realtime/Storage policies
      avoid the active-lot helper.
- [ ] Multi-region failover is out of scope for the single-VM shape.

## 6. Observability

- [x] `/diagnostics` (admins): migrations, stale sessions, open shifts,
      payments, reservations, queues, storage, WhatsApp messages and client
      error reports, with `rpc/diagnostics_snapshot` and
      `rpc/list_client_error_reports`.
- [x] Uncaught Flutter errors go to `client_error_reports` through
      `core/observability` (never throws, never reports expected failures).
- [x] Edge Functions log one JSON line per request.
- [x] `supabase/healthcheck.sh` / `diagnostics.sh` for triage; `restore-drill.sh`
      in CI.
- Recommended alerts: API 5xx > 1 % (5 min), queue backlog > 100, stale sessions
  > 10, disk > 80 %, backup age > 26 h.

## 7. Release checklist

1. `flutter analyze` — 0 errors/warnings (only pinned-SDK deprecation infos).
2. `flutter test` — all green; `supabase/tests/run.sh` — all green.
3. Bump `version:` in `pubspec.yaml`; changelog entry.
4. `flutter build web --release` with `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   `APP_URL`; `flutter build apk --release` (or app bundle) with the same
   defines behind HTTPS.
5. Apply migrations (`docker compose up -d supabase-migrate`) and verify
   `/auth/v1/health`, `/rest/v1/`, `/storage/v1/health`.
6. Smoke: login → check-in → check-out → receipt → shift close → reports →
   `/policies` → `/about`; verify `/diagnostics` has no new alerts.
7. Keep the previous image/APK for rollback; restore uses
   `RESTORE_CONFIRM=yes sh supabase/restore.sh <dir>`.
8. Tag the build once the smoke passes.

## 8. Known limits / next steps

- Single region and self-managed Postgres unless a managed provider is chosen;
  PITR only with that provider.
- The Linux desktop target and its integration suite are not wired yet (AGENTS
  asks for them); CI currently covers web/Android plus the SQL and live-stack
  e2e suites.
- Coverage is measured by `flutter test --coverage` and gated in CI with
  `tool/check_coverage.dart`: global ≥ 70 %, application ≥ 90 %, domain ≥ 35 %,
  infrastructure ≥ 25 %. The layer floors are a ratchet, not the final target
  (AGENTS asks 90 % on domain/infrastructure mappers).
- `idempotency_keys` is purged by cron; confirm the cron is actually running on
  the host (`select * from cron.job` when `pg_cron` is available).
- App distribution is manual (APK/Play upload); no update channel yet.
