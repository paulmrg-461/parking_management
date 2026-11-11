## Why

Regular customers (daily commuters, delivery riders, neighbours) get nothing for coming back. The only tools today are the admin-only manual discount at check-out and (with `add-merchant-validations`) merchant benefits. A lot cannot say "every fifth paid visit is on us" without an operator remembering who is a regular and an admin granting a discount by hand, with no record of why and no protection against gaming (two short stops on the same day, a free pass-holder visit counted as paid, a visit that was later voided).

## What Changes

- **Per-lot loyalty program (NEW settings on `parking_settings`)**: `loyalty_enabled` (default `false`: inert), `loyalty_visits_required` (N), reward kind (`free_stay` up to an optional cap, or `fixed_amount`), qualifying thresholds (`loyalty_min_amount`, `loyalty_min_minutes`), `loyalty_redeem_mode` (`auto` or `operator`), `loyalty_stack_with_merchant`, `loyalty_reward_valid_days`.
- **Per-plate ledger (NEW tables)**: `loyalty_accounts` (progress per lot and normalized plate), `loyalty_visits` (one row per closed session: `counted`, `skipped` with a reason, or `reversed`), `loyalty_rewards` (`available`, `redeemed`, `expired`, `reversed`, with a snapshot of the reward value), `loyalty_adjustments` (manual corrections with reason and actor).
- **Accrual and redemption run in a trigger** on `parking_sessions` (`open` -> `closed`), so `check_out` is NOT re-declared and keeps its 11 arguments. A visit counts only when it was really paid: not a pass holder, not a lost ticket, not `exempt`, `amount_charged >= loyalty_min_amount`, stay `>= loyalty_min_minutes`, at most one counted visit per plate per business day, and a visit that redeemed a reward does not count.
- **The reward is a fare line (REPLACES the no-op hook `fare_reward_step`)** created by `add-merchant-validations`: `fare_quote` calls it after the merchant lines, so the check-out preview, the receipt, the public session page and the history reprint already show it through `fare_adjustments`. The interaction with pricing, merchant benefits and the manual discount is the normative block in `design.md`, identical in the three money changes.
- **Operator choice** in `operator` mode (or "do not use it now" in `auto` mode) through a NEW RPC `choose_loyalty_redemption` called before `check_out`; no new `check_out` parameter.
- **Check-in shows progress**: NEW read RPC `loyalty_plate_status(p_plate)` feeds a chip "Visita 4 de 5" (online only). The entry and exit receipts print the progress and the reward line.
- **Reversal and corrections**: internal `loyalty_reverse_visit(p_session_id)` (for a future void feature; no such feature exists today) and admin RPC `adjust_loyalty_progress` with a mandatory reason, all audited.
- **Admin screen `/loyalty`** (settings, members, report) and `report_loyalty` for a date range with CSV copy and PDF share like the existing reports.
- **Job** `loyalty_expire_rewards()` expires rewards past `expires_at`.

## Capabilities

### New Capabilities

- `loyalty-rewards`: settings, qualifying visits, rewards, redemption, expiry, reversal, adjustments, check-in progress, privacy and the admin report.

### Modified Capabilities

<!-- No MODIFIED requirement: the check-out, check-in and reports specs receive ADDED requirements only, so this change does not collide with the MODIFIED check-out requirement of add-merchant-validations. -->

## Impact

- **Database** (two migrations, next free numbers at implementation time, in this order): `<NEXT>_loyalty_rewards.sql` (settings columns, `parking_sessions.loyalty_choice`, four tables, RLS, audit triggers, plate helper, `fare_reward_step` replacement, closing trigger, status/settings/choice/adjust RPCs, reversal, expiry job) and `<NEXT+1>_loyalty_report.sql` (`report_loyalty`, `list_loyalty_accounts`). Tests in `supabase/tests/rpc_test.sql`.
- **Jobs**: `supabase/jobs.sh` and `supabase/notifications-cron.sh` call `loyalty_expire_rewards`.
- **Flutter**: NEW `lib/features/loyalty/**`, `lib/app/di/modules/loyalty_module.dart`, `lib/app/router/deferred/loyalty_entry.dart`; edits in `lib/features/check_in/presentation/check_in_page.dart`, `lib/features/check_out/presentation/payment_method_dialog.dart`, `lib/core/receipt/receipt_data.dart`, `lib/core/receipt/receipt_labels.dart`, `lib/core/widgets/receipt_card.dart`, `lib/features/receipt_printing/infrastructure/` (thermal and PDF), `lib/app/router/app_router.dart`, `lib/app/shell/app_destinations.dart`, `lib/app/di/injection.dart`, `lib/core/l10n/failure_messages.dart`, ARB files.
- **Dependencies**: none added.
- **Depends on**: `add-merchant-validations` merged first (it creates `fare_quote`, `fare_reward_step` as a no-op, `parking_sessions.fare_adjustments` and `gross_amount`). `add-dynamic-pricing` is independent: either order.
- **Cross-change**: `anomaly_zero_charge_excluded` is NOT touched here: it is type-agnostic (a zero charge whose automatic adjustment lines add up to `gross_amount`), so a reward line registers just by being stored in `fare_adjustments`.
- **Breaking**: none. With `loyalty_enabled = false` the hook returns the no-op value, the trigger returns at once, the check-in chip is hidden and every amount equals today's.

## Non-Goals

- Customer-facing pages, QR cards, WhatsApp or push messages about progress (privacy of plate and visit data; a later change).
- Points, tiers, referral or per-category rules; one program per lot.
- Rewards for monthly-pass holders, lost tickets or exempt exits.
- A void/refund feature for closed sessions (none exists; only the internal reversal function ships).
- Cross-lot accounts (an account is per lot and plate).
- Offline progress display or offline redemption choice (the choice and the chip need the server; the replayed check-out is unaffected).
