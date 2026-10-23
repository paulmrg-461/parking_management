## Why

The whole product assumes exactly one parking lot: `parking_settings` is a
singleton row (`id = 1`), categories/tariffs/vehicles have no lot dimension,
`current_app_role()` derives privileges from a single profile, and the Flutter
shell has no notion of "which lot am I working in". An owner with two sites can
only run two separate databases, and every report, shift and occupancy number
mixes whatever the operators of both sites do.

This change introduces the lot dimension end to end: schema, RLS, RPCs, Flutter
context and reporting. It is planned here because it touches every table and
policy; it is **not** implemented in the current batch.

## What Changes

- New `parking_lots` table (name, slug, address, timezone, active) plus a
  `lot_members` table so a user can work at more than one lot with a role per
  lot (operators commonly float between sites).
- `categories`, `tariffs`, `parking_sessions`, `shifts`, `monthly_passes`,
  `parking_settings`, `category_reservations`, `web_push_subscriptions` and
  `notifications` gain a `lot_id`; `vehicles` stay global by plate but the
  session carries the lot.
- Capacity becomes per `(lot, category)`; tariffs become per `(lot, category)`.
- RLS and every `security definer` RPC resolve the **active lot** from a
  request header (`x-lot-id`) validated against `lot_members`, and deny access
  when it is missing or the user is not a member.
- Flutter: a `LotContext` (core) holds the active lot id, the Supabase client
  sends `x-lot-id` on every request, an admin-only lot switcher lives in the
  shell, and every cached list/Hive box is keyed by lot.
- Reports, occupancy and the dashboard show one lot at a time; admins can
  request an "all lots" consolidated revenue report.

## Capabilities

### New Capabilities

- `parking-lots`: multiple parking sites in one installation — lot CRUD,
  membership per lot, active-lot selection, lot-scoped data isolation (RPCs,
  RLS, capacity, tariffs, reports) and lot-aware offline caches.

### Modified Capabilities

- None at the spec level yet: `capacity`, `shifts`, `reports`, `billing`,
  `monthly-passes` and `notifications` deltas are folded into the new
  capability so the change stays reviewable as one unit.

## Impact

- **Schema (`supabase/migrations`)**: `0023_parking_lots.sql` (tables, backfill
  `lot_id = 1`, `not null` + FKs, unique keys rebuilt as `(lot_id, …)`),
  `0024_lot_rls_and_rpcs.sql` (helpers, policies, RPC signatures with the lot
  resolution), `0025_lot_reports.sql` (per-lot and consolidated reports).
- **RPCs touched**: `check_in`, `check_out`, `calculate_fare`,
  `occupancy_snapshot`, `open_shift`/`close_shift`/`adjust_shift`,
  `create_reservation`, `occupancy_snapshot`, `vehicle_history`,
  `report_revenue`, `report_occupancy`, all reference-data writes, plus new
  `create_lot`, `update_lot`, `set_lot_member`, `list_lots`.
- **Flutter**: `lib/core/lot/` (context + header wiring), `lib/features/lots/`
  (admin CRUD), shell switcher, `SupabaseClient` header injection in
  `injection.dart`, Hive box names/keying by lot, `AppConfig.defaultLot`.
- **Edge Functions**: `push-dispatch` resolves the lot only for filtering;
  `admin-users` gains `lot_id` on create/update.
- **Ops**: `supabase/backup.sh` unchanged, but restores now need the lot rows;
  seeding (`0004`) must create a `default` lot and attach the existing data.
- **Docs**: `README.md`, `AGENTS.md`, `PROGRESS.md`; every RPC example gains the
  `x-lot-id` header.
- **Breaking**: yes for API consumers (header required), none for existing data
  (the migration attaches everything to the default lot).
