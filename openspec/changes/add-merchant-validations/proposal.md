## Why

Neighbouring businesses ask the parking lot to give their customers free or discounted parking ("convenios"). Today the only tool is the admin-only manual discount at check-out (`check_out.p_discount_amount` + `p_discount_reason`, stored in `parking_sessions.discount_*`): an admin must be at the desk, nothing records which business granted the benefit, there are no caps, and nobody can tell a merchant what it owes at the end of the month.

## What Changes

- **Merchants per lot (admin CRUD).** Each merchant has one benefit (`free_minutes`, `percentage` or `fixed_amount`, with an optional cap per validation), a billing mode (`merchant_paid` or `courtesy`), an optional daily and monthly ceiling, a private link token and a 6-digit PIN.
- **Validation by the merchant, without an app account.** A public page `/validate?m=<token>` (same pattern as `/reserve` and `/evidence`): the cashier scans the entry-receipt QR (payload = plate) or types the plate, enters the PIN, and the server records one validation for that plate's open session. Decision and justification in `design.md` (a third auth role was rejected: every lot-scoped RLS policy and `operatorRoutes` assume "authenticated lot member = staff").
- **Validation at the desk.** An operator can register a validation for a merchant on an open session (customer shows a stamped paper), under the same caps.
- **Rules.** One validation per session per merchant; at most `parking_settings.merchant_max_per_session` (default 1) per session; per-merchant daily and monthly ceilings; PIN lock after 5 wrong attempts; admin can revoke a pending validation with a reason.
- **Applied by the server at check-out.** A new internal `fare_quote` function becomes the single place that computes what a session owes; `check_out`, `check_out_preview` and `public_session_summary` call it. The existing manual discount stays as the last step.
- **Shown everywhere the fare is shown.** Check-out preview breakdown, the check-out receipt (screen, PDF, thermal), the reprint from vehicle history and the public QR page list each benefit line.
- **Settlement report per merchant** for a date range (validations, applied, forfeited, discounted amount, amount owed when merchant-paid) with CSV copy and PDF share, like the existing reports.
- **Audit.** Every validation row keeps who/when/how and its final state; `merchants` changes go to `audit_log` through the existing `record_audit` trigger.

## Capabilities

### New Capabilities

- `merchant-validations`: merchants and their benefit, the public validation page, desk validations, caps, PIN lock, revocation, and how the benefit is computed.

### Modified Capabilities

- `check-out`: the amount owed is `gross − automatic adjustments − manual discount`, computed by `fare_quote`; the response and the preview list the adjustments.
- `reports`: adds the merchant settlement report.

## Impact

- **Database (3 new migrations, names fixed, numbers = next free at implementation time, in this order):** `<NEXT>_fare_adjustments.sql`, `<NEXT+1>_merchant_validations.sql`, `<NEXT+2>_merchant_settlement.sql`.
  - New tables: `merchants`, `merchant_validations`.
  - New columns: `parking_sessions.gross_amount`, `parking_sessions.fare_adjustments`, `parking_settings.merchant_max_per_session`.
  - New RPCs: `fare_quote` (internal), `list_merchants`, `save_merchant`, `set_merchant_pin`, `rotate_merchant_token`, `delete_merchant`, `set_merchant_policy`, `list_active_merchants`, `add_merchant_validation`, `revoke_merchant_validation`, `merchant_portal` (anon), `merchant_validate` (anon), `create_merchant_validation` (internal), `report_merchant_settlement`.
  - Redefined in place (same signature): `check_out` (11 args), `check_out_preview(integer)`, `public_session_summary(bigint, text)`, `vehicle_history(text)`.
- **Flutter:** new `lib/core/fare/fare_adjustment.dart`; new feature `lib/features/merchants/`; changes in `lib/features/check_out/` (preview, receipt, DTO, breakdown view, page), `lib/core/receipt/receipt_data.dart`, `lib/core/widgets/receipt_card.dart`, `lib/features/receipt_printing/infrastructure/` (thermal + PDF), `lib/features/vehicle_history/`, `lib/features/evidence/` (public summary), `lib/app/router/` (`/merchants`, `/validate`), `lib/app/shell/app_destinations.dart`, `lib/app/di/`, `lib/core/l10n/failure_messages.dart`, `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`.
- **Env keys:** none new. The merchant link uses the existing `--dart-define=APP_URL` (`lib/core/receipt/evidence_link.dart`); without it on mobile the link cannot be built and the admin screen says so.
- **Dependencies:** none added (`mobile_scanner`, `zxing2`, `printing` are already used by `core/qr` and `core/receipt`).
- **Breaking:** none. With no merchants configured, `fare_quote` returns `adjustments: []` and every amount equals today's.

## Non-Goals

- A merchant login, merchant self-service reports or merchant-side refunds.
- Invoicing the merchant (the settlement report is the input for a manual invoice; electronic invoicing is `add-electronic-invoicing`).
- More than one benefit rule per merchant, purchase-amount thresholds, or time-of-day restrictions on the benefit.
- Queuing validations offline: the public page and the desk validation need the server.
- Changing `report_revenue` (its `total_discounts` keeps meaning "manual discounts").
