## Context

`vehicle-categories` established the CRUD + offline-cache pattern. This change adds
tariffs, the reference data that billing will consume. A tariff is scoped to a
category and carries a type and, for nightly tariffs, a time window that replaces
the day tariff during that window.

## Goals / Non-Goals

**Goals:**
- Tariff CRUD on the backend (list filtered by category; mutations admin-only).
- Validation: positive amount, nightly window rules.
- Flutter `tariffs` feature with offline-cached reads and an admin screen.

**Non-Goals:**
- Billing computation (separate `billing` change).
- Per-tariff effective periods (future).
- Full outbox sync (deferred).

## Decisions

- **Tariff types: `hourly` | `daily` | `nightly` | `monthly`** as an enum, matching
  the business rules. Alternative: separate tables per type — rejected (overkill).
- **Night window stored as "HH:MM" strings** (`start_time`, `end_time`), null for
  non-nightly tariffs. Alternative: `datetime.time` / minutes-since-midnight —
  rejected; "HH:MM" is human-readable, serializes cleanly, and is sufficient for
  hour-based night windows.
- **Nightly requires a window; others must not have one.** Enforced in the service
  (`validate_window`). This keeps the model unambiguous for billing.
- **Amount is a positive integer (COP, no decimals)**, matching the currency rule.
- **`GET /tariffs` filtered by `?category_id=`** to make billing lookup cheap.
- **Reads offline-cached, mutations remote-only** (same pattern as categories).

## Risks / Trade-offs

- [Deleting a category that has tariffs fails via FK] → acceptable for now; an
  explicit guard can be added when billing lands.
- [Window clearing via PATCH is unsupported (null means "unchanged")] → documented;
  recreate the tariff to change its window shape.

## Migration Plan

1. Add the `tariffs` table via Alembic migration with a foreign key to `categories`.
2. Additive only; rollback drops the table.

## Open Questions

- None blocking.
