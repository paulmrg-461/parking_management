## Why

Vehicles carry the license plate that identifies them at check-in and check-out,
plus a category that determines billing. Operators need to register and look up
vehicles quickly (by plate), and admins need to manage them.

## What Changes

- Add a `Vehicle` concept with a unique normalized plate, optional color/brand, and
  a vehicle category.
- Add backend endpoints: `GET /vehicles` (authenticated, optional plate search),
  `POST /vehicles`, `PATCH /vehicles/{id}`, `DELETE /vehicles/{id}` (admin only).
- Add a Flutter `vehicles` feature (hexagonal) with offline-cached reads and an admin
  management screen, plus a plate lookup for future check-in.

## Capabilities

### New Capabilities

- `vehicles`: register/lookup/update/delete vehicles with a normalized unique plate
  and category, admin-only mutations and offline-readable caching.

### Modified Capabilities

(none)

## Impact

- Backend: `Vehicle` model + Alembic migration; `vehicles` router; vehicle repository
  port + SQLAlchemy impl; vehicle service; schemas.
- Flutter: `features/vehicles` feature; `Vehicle` entity + Hive adapter; `VehicleRepository`
  port; remote (Dio) + local (Hive CE) adapters; `VehiclesCubit`; admin screen.
- `openspec/specs/` gains `vehicles` after archive.
