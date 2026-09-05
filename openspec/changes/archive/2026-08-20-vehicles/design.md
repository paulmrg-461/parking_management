## Context

`tariffs` completed the reference-data layer. This change adds vehicles, the entity
check-in/check-out will resolve by plate. The pattern (CRUD + offline cache, admin
mutations, JWT guards) is established and reused.

## Goals / Non-Goals

**Goals:**
- Vehicle CRUD with a normalized, unique plate and a category reference.
- Plate lookup (case-insensitive) for future check-in.
- Flutter `vehicles` feature with offline-cached reads and an admin screen.

**Non-Goals:**
- Check-in/check-out flows (separate changes).
- Automatic plate detection (separate `plate-scanning` change).

## Decisions

- **Plate normalized to uppercase, trimmed, no internal spaces** on write; lookups
  apply the same normalization so searches are case-insensitive. Alternative: store
  raw + index on normalized column — rejected (overkill; plates are short).
- **Color and brand optional** strings; the category reference is required.
- **`GET /vehicles?plate=`** for lookups, plus a `find_by_plate` on the repository.
- **Reads offline-cached, mutations remote-only**, same pattern as categories/tariffs.

## Risks / Trade-offs

- [Deleting a vehicle referenced by future entries will fail via FK] → acceptable;
  entries are not implemented yet; guard deferred.
- [Plate format not strictly validated] → only non-empty normalization enforced, to
  keep the system flexible across plate formats.

## Migration Plan

1. Add the `vehicles` table via Alembic migration with a foreign key to `categories`.
2. Additive only; rollback drops the table.

## Open Questions

- None blocking.
