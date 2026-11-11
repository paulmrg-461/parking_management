## Why

Every stay is paid at the desk today: `check_out` (latest body in `supabase/migrations/0072_billing_integrity.sql`) accepts only `cash`, `card`, `transfer`, `monthly_pass` and `exempt`, and the customer page behind the receipt QR (`/evidence?session=<id>`, `public_session_summary` from `0077`) only *shows* the running fare. At peak hours the exit queue is a payment queue. Customers already hold a link to their session, so they can pay it from their phone (card, PSE, Nequi through Wompi) and drive out; the operator only confirms the exit.

## What Changes

- **Customer pays an open session online.** The public session page gains a "Pay online" panel. It asks the new Edge Function `payment-intent` for a checkout; the amount is priced by the server (`session_settlement`, which wraps `fare_breakdown`), never by the client. The customer is redirected to Wompi Web Checkout.
- **Confirmation only by signed webhook.** The new Edge Function `payment-webhook` verifies Wompi's event checksum with `WOMPI_EVENTS_SECRET` and calls `apply_payment_event` (service role only). The browser redirect is never trusted; the return page only *reads* the intent status. Events are idempotent on `(gateway, gateway_transaction_id, gateway_status)`.
- **Exit grace window.** An approved payment stamps `parking_sessions.online_paid_amount` / `online_paid_at`. A check-out whose exit time is within `parking_settings.online_payment_grace_minutes` (default 15, 5..120) of the approval charges exactly what was paid. After the window the fare is recomputed for the whole stay and only the difference is due at the desk.
- **Operator check-out.** The open-sessions list shows a "Paid online" chip; the check-out dialog shows the paid amount, the balance (if any) and closes without cash when the balance is zero. The server, not the client, sets `payment_method = 'online'`.
- **Reconciliation.** `shift_totals` reports desk money per method net of the online part and a new `online_sales`; online money never enters `expected_cash`. `report_revenue` / `report_revenue_all` split `by_payment` the same way, and a new `report_online_payments` lists the approved transactions for the bank statement.
- **Gateway boundary.** Wompi lives behind a `PaymentGateway` port in `supabase/volumes/functions/_shared/` (one adapter, `wompi_gateway.ts`). SQL and Flutter never mention Wompi.
- **Inert without keys.** With no `WOMPI_*` env the functions answer `PaymentsNotConfiguredError` / `{"configured": false}` and nothing else changes. A lot must also opt in (`parking_settings.online_payments_enabled`, default false).
- **BREAKING (additive contract change):** `parking_sessions.payment_method` and the JSON of `check_out`, `check_out_preview`, `shift_totals`, `public_session_summary` gain values/keys. `shift_totals.cash_sales`, `card_sales` and `transfer_sales` now mean "collected at the desk" (they exclude the online part of a mixed session). No RPC signature changes, so no overload is created.

## Capabilities

### New Capabilities

- `online-payments`: payment intents for open sessions, the gateway port, the signed webhook, idempotent application of gateway events, the exit grace window, the public pay panel, reconciliation of lost webhooks, and the per-lot switch.

### Modified Capabilities

- `payments`: a closed session can store `online`; revenue by payment method separates online from desk money.
- `check-out`: check-out of a session that was paid online (inside and outside the grace window, with a balance, offline replay).
- `shifts`: shift totals separate online collections from the cash drawer.

## Impact

- **Database (3 migrations, next free numbers, in this order):** `<NEXT>_online_payments_schema.sql`, `<NEXT>_online_payments_rpcs.sql`, `<NEXT>_online_payments_checkout.sql`.
  - New tables `payment_intents`, `payment_events`.
  - New columns `parking_settings.online_payments_enabled`, `online_payment_grace_minutes`, `online_payment_min_amount`; `parking_sessions.online_paid_amount`, `online_paid_at`.
  - New RPCs `session_settlement`, `create_session_payment_intent`, `apply_payment_event`, `settle_payment_intent`, `payment_intent_status`, `expire_payment_intents`, `list_reconcilable_payment_intents`, `report_online_payments`.
  - Redefined (same signatures): `check_out`, `check_out_preview`, `public_session_summary`, `shift_totals`, `report_revenue`, `report_revenue_all`, view `open_sessions_view`.
- **Edge Functions (new):** `payment-intent`, `payment-webhook`, `payments-reconcile`, shared `_shared/payment_gateway.ts`, `_shared/wompi_gateway.ts`, `_shared/http.ts`. `supabase/docker-compose.yml`, `supabase/.gitignore`, `supabase/jobs.sh`, `supabase/notifications-cron.sh`.
- **Env keys (server only):** `WOMPI_PUBLIC_KEY`, `WOMPI_PRIVATE_KEY`, `WOMPI_INTEGRITY_SECRET`, `WOMPI_EVENTS_SECRET`, `WOMPI_ENV`, `WOMPI_API_URL`, `WOMPI_CHECKOUT_URL`, `PAYMENT_REDIRECT_BASE_URL`. No client key and no new `--dart-define`.
- **Flutter:** new feature `lib/features/online_payments/`; changes in `lib/features/evidence` (public page + summary entity), `check_out` (entities, DTO, dialog, page), `shifts` (entity, page, PDF), `settings` (entity, DTO, Hive adapter, page), `reports`, `notifications`, `lib/core/receipt`, `lib/core/widgets/receipt_card.dart`, `receipt_printing`, `lib/core/network/supabase_error_mapper.dart`, `lib/core/l10n/failure_messages.dart`, `lib/app/di`, ARB files.
- **Docs:** `CHANGELOG.md`, `docs/project-overview.md`, `docs/database.md`, `docs/architecture.md`, `docs/agent-memory.md`, `.env.example`, `docs/runbook-secrets.md`.
- **Dependencies:** none added (`url_launcher` is already in `pubspec.yaml`; the functions use Web Crypto).

## Non-Goals

- Refunds, chargebacks or voids started from the app (they are done in the Wompi dashboard; the system records a `VOIDED` event and alerts admins).
- Paying at check-in, pre-paying a reservation, tips, partial payments chosen by the customer.
- Card data in the app or the database (Wompi Web Checkout hosts it; PCI scope stays with Wompi).
- Closing the session automatically when the payment is approved (the operator still confirms the exit; `add-barrier-control` automates it later).
- USD lots (Wompi settles in COP; a lot whose `parking_settings.currency` is not `COP` cannot enable the feature).
- One Wompi merchant account per lot (one account per deployment; see Open Questions).
- Monthly-pass charges (delivered by `add-pass-auto-renewal`, which reuses this change's intent table, dispatcher and webhook).
