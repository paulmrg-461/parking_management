Merge protocol: this change re-declares `check_out`, `check_out_preview`,
`public_session_summary` and `vehicle_history`; it MUST be implemented after
`add-online-payments` and re-apply that change's keys (online paid amount and
the `online` method) on top of the new body. See
`openspec/IMPLEMENTATION-ORDER.md`.

Migration numbers: next free at implementation time, in this order
`fare_adjustments` < `merchant_validations` < `merchant_settlement`. SQL tests
go in `supabase/tests/rpc_test.sql` (block `-- merchant validations`), one
`do $$ ... $$` per named case. Money is always integer minor units.

## 1. Database: schema and quote

- [ ] 1.1 Write SQL tests first: Success `quote_without_adjustments_matches_billing`, Success `quote_free_minutes_ceil_to_hour`, Success `quote_percentage_rounds_and_caps`, Success `quote_fixed_amount_never_below_zero`, Success `quote_manual_discount_last`, Failure `quote_discount_above_due` (`InvalidDiscountError`), Security `quote_scoped_to_lot` (`SessionNotFoundError`).
- [ ] 1.2 Create `supabase/migrations/<NEXT>_fare_adjustments.sql`: `parking_sessions.gross_amount`, `fare_adjustments`, `parking_settings.merchant_max_per_session`, `merchants`, `merchant_validations`, RLS (read for lot members, no direct writes), `record_audit()` triggers, indexes `(lot_id, created_at)` and `(session_id)`.
- [ ] 1.3 Implement `fare_quote(p_session_id, p_exit_time, p_discount_amount, p_discount_reason)` (internal, granted to `authenticated`).
- [ ] 1.4 Acceptance: `sh supabase/tests/run.sh`. Definition of done: tests of 1.1 green, no overload created.

## 2. Database: merchant admin RPCs

- [ ] 2.1 Write SQL tests first: Success `create_merchant_returns_token_once`, Failure `duplicate_name` (`DuplicateMerchantError`), Failure `invalid_benefit` (`InvalidDataError`), Success `rotate_token_invalidates_previous`, Success `set_pin_and_lock_after_five_failures` (`MerchantLockedError`), Security `operator_cannot_manage` (`AdminRequiredError`), Security `merchant_rows_scoped_to_lot`, Success `audit_rows_written`.
- [ ] 2.2 Create `supabase/migrations/<NEXT>_merchant_validations.sql` with `list_merchants`, `save_merchant`, `set_merchant_pin`, `rotate_merchant_token`, `delete_merchant`, `set_merchant_policy`.
- [ ] 2.3 Acceptance: suite green; `pg_proc` shows no duplicate overloads.

## 3. Database: validations and settlement

- [ ] 3.1 Write SQL tests first: Success `public_validate_creates_pending`, Failure `unknown_token` (`MerchantNotFoundError`), Failure `wrong_pin_increments`, Failure `no_open_session` (`SessionNotFoundError`), Failure `already_validated` (`AlreadyValidatedError`), Failure `per_session_limit` (`MerchantLimitError`), Failure `daily_and_monthly_caps` (`MerchantCapError`), Success `cap_counts_business_day` (timezone), Success `desk_validation_records_operator`, Success `reserved_plate_not_inside` (`SessionNotFoundError`), Security `other_lot_plate_invisible`, Security `anon_cannot_read_tables` (`insufficient_privilege`), Success `revoke_while_open_only` (`ValidationNotRevocableError`), Success `apply_on_close_marks_applied_and_forfeited`, Success `settlement_sums_applied_only`, Security `settlement_admin_and_lot_only`.
- [ ] 3.2 Create `supabase/migrations/<NEXT>_merchant_settlement.sql` with `merchant_portal`, `merchant_validate`, `add_merchant_validation`, `revoke_merchant_validation`, `report_merchant_settlement`; grant the anon RPCs to `anon, authenticated` after `revoke ... from public, anon, authenticated`.
- [ ] 3.3 Re-declare `check_out`, `check_out_preview`, `public_session_summary` and `vehicle_history` on top of the online-payments bodies, adding `gross_amount`, `fare_adjustments` and the adjustment lines.
- [ ] 3.4 Extend `anomaly_zero_charge_excluded` (from `add-cash-anomaly-detection`) to return true when the session's zero charge comes from a merchant benefit; if that change is not merged yet, leave a comment and a test-free stub.
- [ ] 3.5 Acceptance: suite green; `git diff --stat supabase/migrations` shows only the new files.

## 4. Flutter: domain and infrastructure

- [ ] 4.1 Unit tests first: `Merchant`/`MerchantValidation`/`FareAdjustment` parsing, `Quote` totals, the repository contracts and the error mapping (`DuplicateMerchantError`, `MerchantLockedError`, `AlreadyValidatedError`, `MerchantCapError`, `MerchantLimitError`, `ValidationNotRevocableError`).
- [ ] 4.2 `lib/features/merchants/{domain,infrastructure}`: entities, ports, remote data source (RPCs), repository impl, DTOs; `lib/core/fare/fare_adjustment.dart`; DI module.
- [ ] 4.3 Extend `check_out` entities/DTO with `gross_amount` and `fare_adjustments`; `lib/core/receipt/receipt_data.dart` and `receipt_card.dart` render the lines.
- [ ] 4.4 Acceptance: `flutter test test/features/merchants test/features/check_out`; `flutter analyze`.

## 5. Flutter: screens

- [ ] 5.1 Widget tests first: `/validate` states (loading, wrong PIN, locked, no session, success), admin list/edit/show-key-once/rotate, desk picker in the check-out dialog, settlement report, receipt lines at 400 px.
- [ ] 5.2 Public page `/validate?m=<token>` (route in `authRedirect` public list, mobile-first, plate + PIN, QR scan of the entry receipt).
- [ ] 5.3 Admin `/merchants` (deferred route) and the merchant picker in the check-out dialog; settlement report with CSV/PDF share.
- [ ] 5.4 Receipt, history reprint and public session page show the adjustment lines.
- [ ] 5.5 Acceptance: `flutter test`; `flutter build web --release --no-web-resources-cdn`; 400 px test green.

## 6. Docs and close-out

- [ ] 6.1 `CHANGELOG.md`, `docs/project-overview.md` (§2 status, §3 module `merchants`, §6 jobs if any), `docs/database.md` (tables + RPC catalog + RLS), `docs/agent-memory.md` (design decisions, merge protocol, test count, schema number).
- [ ] 6.2 `openspec archive add-merchant-validations` after the tasks are green.
- [ ] 6.3 Conventional commit and push to `feature/supabase`.
