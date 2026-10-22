# Parking Management — Agent Conventions

## Overview

Parking management system (parqueadero): vehicle registration/control, time-based
billing, vehicle categories, night rates, damage evidence photos, and automatic
license plate detection.

Monorepo:
- `lib/` — Flutter app (targets: `android` + `web`)
- `backend/` — FastAPI + PostgreSQL service (source of truth)
- `openspec/` — specs and changes (spec-driven development via OpenSpec)

## Architecture (MANDATORY)

Hexagonal (Ports & Adapters) + Clean Architecture, organized **by feature**.

```
lib/features/<feature>/
├── domain/           # entities + repository ports (abstract). Depends on nothing.
├── application/      # use cases + cubits (orchestration + state)
├── infrastructure/   # adapters (Isar, REST), models, mappers
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
(offline-first local store), Dio, `go_router`, `camera` + `image_picker`,
`tflite_flutter` + `google_mlkit_text_recognition`, `intl` (COP, no decimals).

Backend: FastAPI, SQLAlchemy 2.0 (async), Alembic, PostgreSQL, JWT, Argon2id.

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
- **Auth storage**: the JWT lives in `flutter_secure_storage` via `TokenStore`;
  Hive only stores the profile. Logout clears reference-data/ETag caches but
  never the outbox.
- **Lists used for lookups** (open sessions, vehicles, monthly passes) must
  walk every backend page; the backend defaults to 100 items per page.
- **Secrets**: production rejects known/example `SECRET_KEY` values, including
  the one in `.env.example`.
- **UI text**: always `context.l10n`; no hardcoded operator-facing strings.

## Spec-driven workflow (OpenSpec)

- Plan with OpenSpec: `openspec new change <name>` then fill proposal → specs → design → tasks.
- Implement via tasks; archive with `openspec archive <name>`.
- Before implementation, read `openspec/changes/<name>/` artifacts.
