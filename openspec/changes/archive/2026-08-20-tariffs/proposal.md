## Why

Tariffs determine how the system charges for parking: per category, by the hour,
by the day, by month, or at a night rate. Without tariffs, billing and check-out
cannot be implemented.

## What Changes

- Add a `Tariff` concept with a type (`hourly`, `daily`, `nightly`, `monthly`), a
  COP amount, an optional night time window (`start_time`/`end_time`, "HH:MM"), and
  an `active` flag, tied to a vehicle category.
- Add backend endpoints: `GET /tariffs` (authenticated, optional category filter),
  `POST /tariffs`, `PATCH /tariffs/{id}`, `DELETE /tariffs/{id}` (admin only).
- Enforce validation: positive amount; nightly requires a valid window; non-nightly
  must not carry a window.
- Add a Flutter `tariffs` feature (hexagonal) with offline-cached reads and an admin
  management screen.

## Capabilities

### New Capabilities

- `tariffs`: create/list/update/delete per-category tariffs (hourly/daily/nightly/
  monthly) with a night window, admin-only mutations and offline-readable caching.

### Modified Capabilities

(none)

## Impact

- Backend: `Tariff` model + Alembic migration; `tariffs` router; tariff repository
  port + SQLAlchemy impl; tariff service with validation; schemas.
- Flutter: `features/tariffs` feature; `Tariff` entity + Hive adapter; `TariffRepository`
  port; remote (Dio) + local (Hive CE) adapters; `TariffsCubit`; admin screen.
- `openspec/specs/` gains `tariffs` after archive.
