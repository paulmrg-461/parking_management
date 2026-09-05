## Context

The `auth` change established the hexagonal vertical-slice pattern across the app
and API (User/AuthSession, repository ports, Dio + Hive CE adapters, JWT guards).
This change applies the same pattern to vehicle categories, the reference data that
tariffs and check-ins will depend on.

## Goals / Non-Goals

**Goals:**
- Category CRUD on the backend (list for any authenticated user; mutations admin-only).
- A Flutter `categories` feature with a repository that caches locally for offline reads.
- An admin screen to manage categories.

**Non-Goals:**
- Tariffs (separate change).
- Deleting a category that is referenced by tariffs/entries (guarding deferred to the
  tariffs change where references exist).
- Bidirectional sync of category edits (deferred to the offline-sync change).

## Decisions

- **Category is just `{id, name}`** with a unique, non-empty name. Alternative: add a
  `code` or vehicle-type enum — rejected (names are configurable and self-describing;
  a type enum would constrain the configurable rule).
- **Reads offline-cached, mutations remote-only**: `list()` tries the backend, caches
  the result in Hive CE, and falls back to the cache on network failure. Mutations
  (create/update/delete) require connectivity and admin role. Alternative: full outbox
  sync now — deferred to the sync change.
- **Admin-only mutations** via the existing `require_admin` dependency; `GET` requires
  only `get_current_user` (operators need categories for check-in).
- **Name uniqueness enforced in the service** (pre-check) and at the DB (unique
  constraint), mapping violations to 409.

## Risks / Trade-offs

- [Offline cache can drift from the server] → the cache is refreshed on every
  successful `list()`; acceptable until full sync lands.
- [Deleting a referenced category could orphan data] → not reachable yet (no tariffs);
  guard will be added with the tariffs change.

## Migration Plan

1. Add the `categories` table via Alembic migration (additive).
2. Ship backend + app together; no destructive change.
3. Rollback: drop the migration and revert.

## Open Questions

- None blocking.
