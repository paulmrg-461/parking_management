## Why

Vehicle categories (moto, car, camioneta, camion, bus) are the backbone of the
parking system: every tariff and every check-in references a category. Operators
need to read categories offline during check-in, and admins need to manage them.

## What Changes

- Add a `Category` concept with a unique, non-empty name.
- Add backend endpoints: `GET /categories` (any authenticated user),
  `POST /categories`, `PATCH /categories/{id}`, `DELETE /categories/{id}`
  (admin only).
- Add a Flutter `categories` feature (hexagonal) with a repository that reads from
  the backend and caches locally in Hive CE so categories remain available offline.
- Add an admin "Categories" screen and a route guard entry.

## Capabilities

### New Capabilities

- `vehicle-categories`: list/create/update/delete vehicle categories, with admin-only
  mutations and offline-readable caching.

### Modified Capabilities

(none)

## Impact

- Backend: `Category` model + Alembic migration; `categories` router; category
  repository port + SQLAlchemy impl; category service; schemas.
- Flutter: `features/categories` feature (domain/application/infrastructure/
  presentation); `Category` entity + Hive adapter; `CategoryRepository` port;
  remote (Dio) + local (Hive CE) adapters; `CategoriesCubit`; admin screen.
- `openspec/specs/` gains `vehicle-categories` after archive.
