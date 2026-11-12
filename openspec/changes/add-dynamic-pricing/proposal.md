## Why

Prices are flat: a car pays 3000 per hour at 10:00 on a Tuesday and at 18:00 on a full Friday, and a lot at 95 % occupancy has no lever to ration the last spaces or to fill a quiet night. Owners ask for "hora pico", "noche valle" and "evento" prices, but only if no customer ever pays a rate they were not shown.

## What Changes

- **Pricing rules (NEW table `public.pricing_rules`)**: per lot, optional vehicle group, occupancy band, weekday mask and local time window (may cross midnight), effect = multiplier (basis points) and/or flat surcharge, `priority` (highest wins, no stacking). Admin CRUD through RPCs, audited by `record_audit()`.
- **Lot guard rails (NEW `parking_settings` columns)**: `pricing_enabled` (default false, inert), `pricing_floor_bps`, `pricing_ceiling_bps`, `pricing_round_to`.
- **Rate locked at entry**: a `BEFORE INSERT` trigger on `parking_sessions` writes `pricing_lock` (a JSON snapshot of the winning rule and the guard rails) using `new.entry_time`; the lock is immutable and is the only thing read at check-out, so occupancy, rule edits or the exit time never change a parked car's rate. `check_in` keeps its 11-argument signature.
- **Public holds promise a price**: a `/reserve` hold stores its own lock (identity lock when no rule applies); the session that consumes the hold takes the cheaper of the hold lock and the lock computed now. Offline-replayed check-ins can never be surcharged.
- **Applied through the hook**: replaces `fare_pricing_step` (a no-op owned by `add-merchant-validations`); `fare_quote`, `check_out`, `check_out_preview` are not re-declared. Pricing changes the gross (`gross_amount`), it is not an adjustment line.
- **Shown before and after**: new keys on `public_availability` (`current_hourly_amount`, `price_rule`, `price_multiplier_bps`, `price_tier`), `pricing_quote` for the check-in screen, the applied rule in the fare breakdown, the entry/check-out receipts (screen, PDF, thermal), the reprint and the public QR page.
- **Admin tools**: `pricing_simulate` previews rules (saved or draft) against the last N days of real sessions; `report_pricing_impact` shows the real effect.
- **Flutter**: NEW feature `lib/features/pricing/` (`/pricing` admin page, rule dialog, simulation sheet, check-in price chip), additive edits to public booking, check-in, check-out, receipts, reports, ES/EN strings.

## Capabilities

### New Capabilities

- `dynamic-pricing`: rules, guard rails, rate lock at entry, hold promise, offline rule, quote and public price, hook application, simulation, impact report, audit and isolation.

### Modified Capabilities

- `check-in`: a new session gets its rate locked at insert; the screen shows the current price; the entry receipt shows the locked rate.
- `check-out`: the gross fare includes the locked pricing rule and the breakdown and receipt list it.
- `reports`: adds the pricing impact report.

## Impact

- **Database** (two migrations, next free numbers at implementation time, in this order): `<NEXT>_dynamic_pricing.sql` (settings columns, `pricing_rules`, `pricing_lock` columns, pure functions, triggers, the replaced `fare_pricing_step`) and `<NEXT+1>_dynamic_pricing_rpcs.sql` (admin RPCs, quote and lock reads, simulation, report, `pricing_decorate_availability`, wrapper over `public_availability`). Regression tests in `supabase/tests/rpc_test.sql`.
- **Flutter**: `lib/features/pricing/**` (NEW), `lib/features/check_in/presentation/check_in_page.dart`, `lib/features/check_out/domain/entities/check_out_preview.dart` + `check_out_receipt.dart` + DTO + `presentation/widgets/fare_breakdown_view.dart`, `lib/features/public_booking/**`, `lib/features/vehicle_history/**`, `lib/features/evidence/**` (public summary), `lib/features/reports/**`, `lib/core/receipt/receipt_data.dart` + `receipt_labels.dart`, `lib/core/widgets/receipt_card.dart`, `lib/features/receipt_printing/infrastructure/*`, `lib/app/router/app_router.dart` + `deferred/pricing_entry.dart`, `lib/app/shell/app_destinations.dart`, `lib/app/di/injection.dart` + `modules/pricing_module.dart`, `lib/core/l10n/failure_messages.dart`, ARB files.
- **Config / dependencies**: none.
- **Depends on**: `add-online-payments` and `add-merchant-validations` merged first (it needs `fare_quote`, `fare_pricing_step`, `parking_sessions.gross_amount`). Independent of `add-loyalty-rewards` (either order).
- **Order and merge protocol**: wave 4 of `openspec/IMPLEMENTATION-ORDER.md`, after merchants. It replaces only `fare_pricing_step` and wraps `public_availability`; the owner should add this change to that file.
- **Breaking**: none. With `pricing_enabled = false` (default) no lock is written and every amount equals today's.

## Non-Goals

- Rule stacking, forecast-based prices, per-minute repricing of parked cars.
- Pricing monthly pass sales, lost-ticket fees or the manual discount.
- Editing rules or settings offline; nothing here is queued in the sync outbox or added to the versioned (`version`) set.
- Changing tariffs, the night window, the daily cap or `fare_breakdown`.
- A customer-chosen price or auctions; online payment of any amount other than the one the server computes.
