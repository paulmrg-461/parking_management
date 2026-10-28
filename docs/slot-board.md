# Space board and fare settlement

Component and data-flow reference for the operator's two busiest screens: the
space board on the home dashboard and the settlement dialog at check-out.
Both read money from the server only; the client never computes a fare.

- Status: implemented (migrations `0052` and `0053`).
- Screens: `/` (board), `/check-out` (settlement), space details bottom sheet.

## 1. Space board

The site has capacity counts per group (cars + pickups, motorcycles), not
physical bay numbers, so the board paints **virtual capacity cells**: the first
cells are the vehicles inside, then the active holds, then the spots the admin
took out of service (striped), then free cells. A group with capacity `0`
means "no limit" and only paints the vehicles inside (`Pesados`/heavy: trucks
and buses are not limited).

Free spots are `capacity - sessions - holds - out_of_service`, clamped to
zero. Out-of-service spots are set in Ajustes and are **never offered**: the
capacity trigger, `create_reservation`, the dashboard snapshot and the
check-in remaining-spaces labels all use `usable_capacity()`.

| State | Meaning | Colour (semantic token) | Cell content |
| --- | --- | --- | --- |
| Free | Spot available | `StatusColors.success` (emerald) tint + border | group icon, `Libre`, index |
| Occupied | Open session | `ColorScheme.primary` tint, neutral border | plate (monospace), live elapsed time |
| Reserved | Active hold | `StatusColors.pending` (amber) tint | plate, expiry time (`HH:mm`) |
| Maintenance | Spot taken out of service by an admin | grey hatch (`ColorScheme.outline`) | build icon, `Mantenimiento` (not tappable) |

The state is never conveyed by colour alone: each cell also carries a text
label (`Libre`/`Ocupado`/`Reservado` in the tooltip and semantics) and a
distinct icon per group.

### Layout

- Cell target size is 76 px; the grid derives its column count from the
  available width (`width / 76`, clamped 2–12) so cells stay square and the
  card fills the column on phones, tablets and the wide dashboard.
- Group headers show the group icon, its label and `free / capacity`.
- Filters are `ChoiceChip`s with icons: **Todos**, **Carros**, **Motos** and
  **Reservas** (only shown when holds exist). Chips and cells keep a ≥ 44×48 dp
  tap area for cabin tablets.
- The header shows a green chip with the immediate free spots
  (`N libres`), computed as `capacity - sessions - holds` clamped to zero.

### Interactions

- Tap an occupied cell → bottom sheet with the plate, exact entry time, a
  one-second live clock, pass/keys/photo chips, the server fare breakdown and a
  primary **Salida** action that opens `/check-out?scan=<plate>`.
- Tap a reserved cell → bottom sheet with the plate and hold expiry. Admins
  additionally get **Cancelar reserva** (confirmation + snack + board reload);
  the reservation id is resolved from `listActive()` by plate and expiry, since
  the board payload carries no id.
- Free cells are not interactive (no dead-end sheets).

### UI states

| State | Rendering |
| --- | --- |
| Loading | Card skeleton with a title bar and 12 cell placeholders |
| Success | Interactive grid with filters and per-group headers |
| Empty | Empty state ("Configure the parking spaces") plus an admin shortcut to `/settings` |
| Error | Inline error card with the mapped failure message and a retry button |

Rendering lives in
`lib/features/home/presentation/widgets/slot_board_card.dart`; the cubit keeps
`slotBoard` in `DashboardLoaded` and exposes `preview(sessionId)` for the
sheet. A board failure never blocks the rest of the dashboard (it falls back to
`SlotBoard.empty`).

## 2. Settlement and fare explanation

`check_out_preview` returns the charge **and** its breakdown: elapsed seconds,
billed day hours, billed night hours, charged days, hourly/nightly/daily rates,
and whether a daily cap applied. `fare_breakdown` is the single source of truth:
`calculate_fare` is now a thin wrapper over it, so the preview can never drift
from the amount charged at check-out.

The settlement dialog (`payment_method_dialog.dart`) shows:

1. `Liquidación` + "charge the exit of <plate>?".
2. `FareBreakdownView`: time, `N h × $rate (día)`, `N h × $rate (noche)`, the
   daily cap note, and the total (`Total a cobrar`). A monthly pass shows
   "covered by the monthly pass" and a zero total.
3. Payment method (cash, card, transfer, monthly pass) with icons.
4. Lost-ticket checkbox + reason and, for admins, the audited discount.
5. `Confirmar` closes the session and the receipt sheet follows (print/screen/
   share).

If the preview fails (offline, session already closed) the dialog still opens
with the methods and a muted "the fare could not be calculated" line, so the
operator is never blocked from closing a session.

## 3. Data contract

```sql
-- 0052: visual board of the active lot
slot_board() returns jsonb
-- { car_capacity, moto_capacity, car_out_of_service, moto_out_of_service,
--   sessions: [{session_id, plate, entry_time, left_keys, photo_count,
--               has_pass, group: car|moto|heavy}],
--   holds:    [{plate, reserved_until, group}] }

usable_capacity(capacity, out_of_service) returns integer
-- configured minus out of service; `0` capacity (no limit) stays `0`

-- 0053: money, single source of truth
fare_breakdown(category_id, entry, exit, has_pass) returns jsonb
-- { amount, hourly_rate, nightly_rate, daily_rate, day_hours, night_hours,
--   days, daily_cap_applied, elapsed_seconds }

check_out_preview(session_id) returns jsonb
-- fare_breakdown || { session_id, amount, has_pass, entry_time, previewed_at }
```

`slot_board()` is `security definer` and resolves the lot through the mandatory
`x-lot-id` header (`current_lot_id()`), like every site-owned RPC. Groups are
derived from the category name: `car/carro/auto/camioneta/suv` → car,
`moto/motos/motorcycle` → moto, anything else → heavy.

## 4. Accessibility (WCAG 2.2 AA)

- Every cell is a `Semantics` node with a label that states the state, the plate
  and the context (`Ocupado ABC123, 2 h 05 min`), button flag for interactive
  cells, and the same text as a `Tooltip`.
- Filters are real chips with ≥ 44×48 dp targets and visible labels; nothing
  relies on hover.
- Text uses `onSurface`/`onSurfaceVariant` over the tinted cell background;
  semantic tokens keep ≥ 4.5:1 in light and dark themes (`status_colors_test`).
- Reduced motion disables the occupancy bar animation; the settlement sheet
  uses no auto-playing motion.
- The live clock is text inside the sheet; screen readers announce the value
  when focus enters the cell, not once per tick.

## 5. Known limits

- No physical bay numbers or bicycles in the data model, so the board is a
  capacity map. "Out of service" is a count per group, not a specific bay.
  Adding bay rows later would only replace the free-cell generator, not the
  card.
- The live amount refreshes every 60 s (and the clock every second) to avoid
  hammering the RPC; the authoritative amount is still the one computed at
  check-out.
- The entry form keeps its text field plus lookup (USB readers and keyboards),
  suggests known plates after two characters, and opens an on-screen
  alphanumeric keypad from the field (and from the check-out search).

## 6. Tests

- `test/features/home/presentation/home_page_test.dart`: cell states, filters,
  empty/error states, detail sheet + direct exit, semantics labels, tap-target
  size, radial occupancy gauge, free cells not interactive.
- `test/features/check_out/presentation/check_out_page_test.dart`: settlement
  breakdown (day/night/cap/total), broken-preview fallback.
- `test/features/check_out/domain/{check_out_preview,slot_board,capacity_snapshot}_test.dart`:
  parsing, zeroed legacy payloads, unknown-group isolation, usable-pool math.
- `supabase/tests/rpc_test.sql`: `fare_breakdown` equals `calculate_fare`,
  night split, daily cap, pass zero-charge, invalid period, board RPC, and
  out-of-service check-in/reservation refusal (plus a usable-spot oversell
  guard).
