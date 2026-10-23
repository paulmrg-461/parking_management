## Context

Everything is single-lot today: `parking_settings` is the singleton row
`id = 1`, `categories.name` and `vehicles.plate` are globally unique,
`enforce_category_capacity()` counts open sessions per category,
`calculate_fare()` reads the category's tariffs, shifts belong to one operator
and every report aggregates the whole database. `public.users` mirrors
`auth.users` with a single `role`, and the Flutter app never sends a site
identifier because there is only one.

Two facts shape the design:

1. The Flutter client talks to PostgREST directly, so row scoping has to happen
   in RLS + RPCs, not in an application server.
2. Operators float between sites; a strict "one lot per user" model would need
   a separate login per site, which the product explicitly does not want.

## Goals / Non-Goals

**Goals:**

- Several lots in one installation, each with its own categories, tariffs,
  capacity, shifts, passes, settings, reservations and reports.
- A user can hold a role per lot; admins can consolidate reports across lots.
- Lot isolation enforced in the database (RLS + RPCs), never only in the UI.
- One-time, reversible migration: existing data lands in a `default` lot.
- Offline caches never mix data from two lots.

**Non-Goals:**

- Cross-lot vehicle transfers or a shared fleet of "global" vehicles beyond the
  plate identity (a plate can park at any lot; its history is per lot).
- Per-lot billing/receipt numbering sequences with independent resets (v1:
  ticket numbers stay globally unique, prefixed by lot code).
- Per-lot theming/branding assets beyond what `parking_settings` already holds.
- Moving to schema-per-lot, separate databases or a tenant-id claim baked into
  the JWT (that would require a re-login to switch sites).

## Decisions

### 1. Active lot travels in `x-lot-id`, validated by a helper

`PostgREST` forwards request headers as `current_setting('request.headers')`.
A `security definer` helper resolves the active lot:

```sql
create or replace function public.current_lot_id()
returns integer language plpgsql stable security definer set search_path = public as $$
declare
    raw text := coalesce(
        current_setting('request.headers', true)::json ->> 'x-lot-id', ''
    );
    uid integer := public.current_app_user_id();
    lot integer;
begin
    if raw ~ '^[0-9]+$' then lot := raw::integer; end if;
    if lot is null then
        select min(lm.lot_id) into lot from public.lot_members lm where lm.user_id = uid;
    end if;
    if lot is null or not exists (
        select 1 from public.lot_members lm where lm.user_id = uid and lm.lot_id = lot
    ) then
        raise exception 'LotRequiredError';
    end if;
    return lot;
end $$;
```

Rejected alternatives:

- **JWT claim**: switching lots would need a token refresh/relogin; the header
  can switch per request and keeps the session.
- **One lot per user**: forces duplicate accounts for floating operators.
- **`p_lot_id` on every RPC only**: reads through PostgREST (tables, views)
  would still leak across lots; RLS needs the same source of truth.

The default when the header is missing is the user's smallest `lot_members`
lot, which keeps single-lot installations and the migration path working
without a client change on day one.

### 2. `lot_members` is the authorization table, `users.role` stays global

`users.role` remains the platform role (`admin` can create lots and move
people); `lot_members(role)` is what operators are checked against for
lot-scoped actions. `require_admin()` keeps meaning "platform admin", and a new
`require_lot_admin()` means "admin of the active lot". A lot admin can manage
categories, tariffs, passes and users **of his lot** but cannot create lots or
promote anyone to platform admin.

### 3. Vehicles stay global; sessions carry the lot

`vehicles.plate` remains unique per installation: the same car can park at any
site and its `vehicle_history` becomes lot-scoped (a filter, not a hard RLS
wall — an admin may need the plate's history across lots for a dispute). The
session, its payment, its shift and its evidence belong to the lot where it
happened.

### 4. Capacity and tariffs are `(lot, category)`

`categories` gains `lot_id` and `unique (lot_id, name)`; `tariffs` gain
`lot_id` and keep `(category_id, type)` uniqueness (the category already
identifies the lot, but storing it avoids a join in `calculate_fare` and lets
RLS filter tariffs without the join). `enforce_category_capacity()` counts
`parking_sessions` for `(lot_id, category_id)`, reservations included.

### 5. Ticket numbers get a lot prefix

Global uniqueness is kept (`uq_sessions_ticket`) with `TCK-<lotcode>-000123`;
the sequence stays per session id, so no per-lot counter table is needed in v1.
Receipts already print the ticket number verbatim.

### 6. Shifts are per `(operator, lot)`

`uq_open_shift_per_operator` becomes `unique (operator_id, lot_id) where
closed_at is null`: an operator working two sites in one day opens one shift per
site. `expected_cash` sums only the sessions of that shift.

### 7. Flutter: one `LotContext`, header on every request, lot-keyed caches

- `LotContext` (core singleton) holds `activeLotId` + the member list, persisted
  in Hive so a cold start offline still knows the lot.
- `injection.dart` registers `SupabaseClient.global.headers['x-lot-id']` from a
  mutable holder that `LotContext` updates; changing lots re-creates nothing but
  refreshes the cubits (dashboard, shifts, lists).
- Hive boxes that cache lot data (`vehicles` page cache, passes, notifications,
  vehicle history) key entries by `lotId` so switching never shows stale rows.
- A `LotCubit` exposes the members list for the shell switcher (admins and
  multi-lot operators); a single-lot operator sees no switcher.

### 8. Offline check-in/out resolve the lot at capture time

The outbox payload carries `lot_id` (captured when the operator acted) and the
replayer sends `x-lot-id` for that request. A queued mutation must land in the
site where it happened even if the operator switched lots before reconnecting.

### 9. Reports: per lot by default, consolidated for admins

`report_revenue(p_start, p_end)` keeps its signature and filters by
`current_lot_id()`. A new `report_revenue_all(p_start, p_end)` is available to
platform admins and returns rows grouped by lot plus a total.

### 10. Rollout is expand → migrate → contract

1. **Expand**: create `parking_lots` + `lot_members`, seed a `default` lot, add
   nullable `lot_id` columns, backfill everything to the default lot, create
   the default membership for every existing user.
2. **Migrate**: set `not null` + FKs, rebuild the unique keys as
   `(lot_id, …)`, replace RPCs and policies (header + fallback), ship the
   Flutter release that sends the header.
3. **Contract**: drop the fallback default after one release (a follow-up
   change), so a missing header fails loudly instead of silently writing to the
   default lot.

## Risks / Trade-offs

- **[Header spoofing]** → The header is only a *selector*; `current_lot_id()`
  validates membership on every call, so a forged value yields
  `LotRequiredError` and never another lot's rows.
- **[Forgotten RLS policy]** → A policy that keeps `using (true)` would leak
  across lots. Mitigation: a SQL regression test per lot-scoped table that
  inserts rows for two lots and asserts the count seen with each header, plus a
  `pgTAP`-style check that every table with a `lot_id` column has a policy
  mentioning `current_lot_id()` (catalog query in `tests/`).
- **[Reads before the client sets the header]** → The fallback (smallest
  membership) keeps the first release working; the console/Studio and Edge
  Functions must pass the header or an explicit lot parameter.
- **[Unique keys rebuilt]** → `categories.name` uniqueness must become
  `(lot_id, name)` or two lots cannot both have "car". The migration drops and
  recreates indexes; a duplicate-name test guards it.
- **[Text search / vehicle lookup]** → `findByPlate` stays global (a plate can
  exist at any lot) but its history and open-session badge are lot-scoped; a
  test asserts an open session at lot B is not reported at lot A.
- **[Effort]** → ~10-14 dev days: 4 for migrations/RLS/RPCs, 3 for Flutter
  context + caches, 2 for the admin lot UI, 2 for reports/notifications, 1-2 for
  tests and docs. Not started in this batch.

## Migration Plan

1. `0023_parking_lots.sql`: tables, seed `default` lot (code `DEF`), backfill
   `lot_id` on every scoped table, default membership for every existing user.
2. `0024_lot_rls_and_rpcs.sql`: helpers (`current_lot_id`, `require_lot_admin`),
   policies, and every RPC signature that gained lot resolution.
3. Flutter: `LotContext` + header wiring + switcher + lot-keyed caches.
4. Verification: SQL suite runs twice (two lots, headers) and the Flutter suite
   covers single-lot (no header) and multi-lot (switching) paths.
5. Rollback: the expand step is additive. Rolling back the app before the
   contract step leaves data in the default lot, which the old code reads
   normally (the columns are simply ignored).
