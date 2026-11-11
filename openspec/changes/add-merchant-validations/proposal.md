## Why

Neighbouring businesses ask the parking lot to give their customers free or discounted parking ("convenios"). Today the only tool is the admin-only manual discount at check-out (`check_out.p_discount_amount` + `p_discount_reason`, stored in `parking_sessions.discount_amount/reason/by/at`, `0011` and `0072`): an admin must be at the desk, nothing records which business granted the benefit, there are no caps, and nobody can tell a merchant what it owes at the end of the month.

## What Changes

- **Merchants per lot (admin CRUD, NEW table `public.merchants`)**: each merchant has one benefit (`free_minutes`, `percentage` or `fixed_amount`, with an optional cap per validation), a billing mode (`merchant_paid` or `courtesy`), optional daily and monthly validation ceilings and an active flag. Credentials live in a separate NEW table `merchant_credentials` (private link token hash + bcrypt PIN hash + lock state) so no secret ever reaches `audit_log`.
- **Validation by the merchant without an app account**: a NEW public page `/validate?m=<token>` (same pattern as `/reserve` and `/evidence`). The cashier scans the entry-receipt QR (payload = plate) or types the plate, enters the 6-digit PIN, and the server records one `pending` validation for that plate's open session. Decision and justification in `design.md` (a third auth role was rejected: every lot-scoped RLS policy and `operatorRoutes` assume "authenticated lot member = staff").
- **Validation at the desk**: an operator can register a validation for a merchant on an open session from the check-out dialog, under the same caps. An admin can revoke a pending validation with a reason.
- **Rules**: one validation per session per merchant; at most `parking_settings.merchant_max_per_session` (NEW, default 1, `0` disables) per session; per-merchant daily and monthly ceilings; the PIN locks after 5 wrong attempts for 15 minutes; the benefit terms are snapshotted on the validation.
- **Applied by the server at check-out**: a NEW internal `fare_quote` function becomes the single place that composes what a session owes (base, pricing hook, merchant lines, reward hook, manual discount); `check_out`, `check_out_preview`, `public_session_summary` and `vehicle_history` use it. It also owns two no-op extension hooks (`fare_pricing_step`, `fare_reward_step`) that `add-dynamic-pricing` and `add-loyalty-rewards` replace, and the type-agnostic `anomaly_zero_charge_excluded` rule. The exact interaction of the three money changes is the normative block in `design.md`, copied verbatim in all three.
- **Shown everywhere the fare is shown**: check-out dialog breakdown, check-out receipt (screen, PDF, thermal), reprint from vehicle history and the public QR page list each benefit line.
- **Settlement report per merchant** for a date range (validations, applied, forfeited, revoked, discounted amount, amount owed when merchant-paid) with CSV copy and PDF share like the existing reports.
- **Audit**: `merchants` and `merchant_validations` carry the existing `record_audit()` trigger; each validation row keeps who, when, how and its final state.

## Capabilities

### New Capabilities

- `merchant-validations`: merchants and their benefit, credentials, the public validation page, desk validation, caps, PIN lock, revocation, composition of the amount owed (`fare_quote` and its hooks), application at check-out, and the settlement report.

### Modified Capabilities

- `check-out`: the amount owed is `gross - automatic adjustments - manual discount`, composed by `fare_quote`; the response and the preview list the adjustments.
- `reports`: adds the merchant settlement report.

## Impact

- **Database (3 migrations, next free numbers at implementation time, in this order; head today is `0108` or higher):** `<NEXT>_merchants.sql` (columns, tables, RLS, audit triggers, admin RPCs), `<NEXT+1>_fare_quote.sql` (hooks, `fare_quote`, re-declared `check_out`, `check_out_preview`, `public_session_summary`, `vehicle_history`, anomaly extension) and `<NEXT+2>_merchant_validations.sql` (public and desk RPCs, settlement report).
  - New tables: `merchants`, `merchant_credentials`, `merchant_validations`.
  - New columns: `parking_sessions.gross_amount`, `parking_sessions.fare_adjustments`, `parking_settings.merchant_max_per_session`.
  - New RPCs: `list_merchants`, `list_active_merchants`, `save_merchant`, `reset_merchant_credentials`, `delete_merchant`, `set_merchant_policy`, `add_merchant_validation`, `revoke_merchant_validation`, `merchant_portal` (anon), `merchant_validate` (anon), `report_merchant_settlement`; internal `fare_quote`, `fare_pricing_step`, `fare_reward_step`, `create_merchant_validation`, `merchant_hash_token`.
  - Redefined in place (same signature, no overload): `check_out` (11 args), `check_out_preview(integer)`, `public_session_summary(bigint, text)`, `vehicle_history(text)`, and `anomaly_zero_charge_excluded(integer)` when `add-cash-anomaly-detection` is merged.
- **Flutter:** NEW `lib/core/fare/fare_adjustment.dart`, `lib/core/fare/fare_quote.dart`, feature `lib/features/merchants/`; changes in `lib/features/check_out/` (preview entity, receipt entity and DTO, `fare_breakdown_view.dart`, `payment_method_dialog.dart`, `check_out_page.dart`), `lib/core/receipt/receipt_data.dart`, `lib/core/receipt/receipt_labels.dart`, `lib/core/widgets/receipt_card.dart`, `lib/features/receipt_printing/infrastructure/` (thermal + PDF), `lib/features/vehicle_history/`, `lib/features/evidence/domain/entities/public_evidence.dart`, `lib/app/router/` (`/merchants`, `/validate`), `lib/app/shell/app_destinations.dart`, `lib/app/di/`, `lib/core/l10n/failure_messages.dart`, `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`.
- **Env keys:** none new. The merchant link uses the existing `--dart-define=APP_URL` (`lib/core/receipt/evidence_link.dart`); without it on mobile the admin screen shows the path only.
- **Dependencies:** none added (`mobile_scanner`, `zxing2`, `printing` are already used by `core/qr` and `core/receipt`).
- **Order and merge protocol:** after `add-online-payments` (wave 4, `openspec/IMPLEMENTATION-ORDER.md`); `add-dynamic-pricing` and `add-loyalty-rewards` come after this change and only replace the two hooks.
- **Breaking:** none. With no merchants configured `fare_quote` returns `adjustments: []` and every amount equals today's.

## Non-Goals

- A merchant login, merchant self-service reports or merchant-side refunds.
- Invoicing the merchant (the settlement report is the input for a manual invoice; electronic invoicing is `add-electronic-invoicing`).
- More than one benefit rule per merchant, purchase-amount thresholds, or time-of-day restrictions on the benefit.
- Queuing validations offline: the public page and the desk validation need the server, and nothing is written to the sync outbox.
- Changing `report_revenue` (its `total_discounts` keeps meaning "manual discounts").
- Making merchants part of the versioned set of `0105` (they are online-only admin data).
