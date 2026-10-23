# Tasks — add-multi-parking-lot (planned, not started)

## 1. Schema and backfill

- [ ] 1.1 Write the SQL regression tests first: two lots with identical category
      names coexist; capacity is enforced per lot; a session created at lot A is
      invisible with `x-lot-id: B`; a missing header falls back to the user's
      default lot; a non-member header raises `LotRequiredError`
- [ ] 1.2 `0023_parking_lots.sql`: `parking_lots` (name, code, address,
      timezone, active) and `lot_members` (user_id, lot_id, role) with FKs,
      unique keys and a seeded `default` lot
- [ ] 1.3 Add nullable `lot_id` to categories, tariffs, parking_sessions,
      shifts, monthly_passes, monthly_pass_payments, category_reservations,
      parking_settings, notifications and web_push_subscriptions; backfill every
      row to the seeded lot; insert a `lot_members` row per existing user
      (platform role preserved)
- [ ] 1.4 Set `not null`, add FKs with `on delete restrict`, rebuild unique keys:
      `categories (lot_id, name)`, `shifts (operator_id, lot_id) where closed_at
      is null`, `parking_settings` becomes per lot (drop the `id = 1` singleton)
- [ ] 1.5 `enforce_category_capacity()` counts by `(lot_id, category_id)` and
      includes reservations; `calculate_fare()` keeps working through the
      category's lot

## 2. RLS and RPCs

- [ ] 2.1 Add `current_lot_id()` (header + membership validation + fallback) and
      `require_lot_admin()`; unit-test both with a header present, absent,
      forged and for a non-member
- [ ] 2.2 Rewrite every lot-scoped policy to `using (lot_id = current_lot_id())`
      (select) and the matching `with check` for writes; keep `vehicles` global
      with `vehicles_read` untouched
- [ ] 2.3 Add `create_lot`, `update_lot`, `list_lots`,
      `set_lot_member` (platform-admin only) and `my_lots()` for the switcher
- [ ] 2.4 `check_in`/`check_out` derive the lot from `current_lot_id()` (never
      from the client), write it on the session, prefix the ticket with the lot
      code and validate payment/shift lot consistency
- [ ] 2.5 Shifts: `open_shift`/`close_shift`/`adjust_shift` are per
      `(operator, lot)`; `shift_totals` sums only that lot's sessions
- [ ] 2.6 Reservations, passes, notifications and `push-dispatch` include the
      lot; `vehicle_history` takes an optional lot filter and returns the lots
      where the plate has visited
- [ ] 2.7 `report_revenue`/`report_occupancy` filter by `current_lot_id()`;
      add `report_revenue_all` for platform admins grouped by lot

## 3. Flutter: lot context

- [ ] 3.1 Tests first: `LotContext` persists and restores the active lot;
      switching refreshes the dashboard/shift/list cubits; a single-member user
      never sees the switcher; an offline cold start keeps the last lot
- [ ] 3.2 `lib/core/lot/`: `Lot`, `LotMember`, `LotContext` (Hive-backed) and a
      `LotRepository` port mapped to `my_lots`/`list_lots`
- [ ] 3.3 `injection.dart`: mutable header holder wired into
      `SupabaseClient.global.headers['x-lot-id']`, updated by `LotContext`
- [ ] 3.4 `lib/features/lots/`: admin CRUD page (deferred route + nav entry) and
      the shell switcher (bottom sheet on narrow, dropdown on wide)
- [ ] 3.5 Key every lot-scoped Hive cache by `lotId` (vehicles page cache,
      passes, notifications, history) and clear the in-memory cubits on switch
- [ ] 3.6 Outbox mutations capture `lot_id` at enqueue time and the replayers
      send `x-lot-id` for the captured lot

## 4. UI and reports

- [ ] 4.1 Receipts print the lot name/address from the active lot's settings;
      the ticket shows the lot code
- [ ] 4.2 Dashboard, occupancy, shift and reports pages show the active lot in
      the app bar; admins get an "all lots" toggle on the revenue report
- [ ] 4.3 Settings become per lot (form edits the active lot); platform-level
      branding (app name) stays global

## 5. Edge Functions, docs and rollout

- [ ] 5.1 `admin-users` accepts `lot_id` and creates the matching
      `lot_members` row; `push-dispatch` filters subscriptions per lot when the
      notification carries one
- [ ] 5.2 Update `README.md` (header, lot creation, migration), `AGENTS.md`
      (invariants: active lot always from the server helper) and `PROGRESS.md`
- [ ] 5.3 Run the full suite: `flutter test`, `flutter analyze`,
      `supabase/tests/run.sh`, web build, and a manual two-lot smoke test
- [ ] 5.4 Follow-up contract migration dropping the header fallback
