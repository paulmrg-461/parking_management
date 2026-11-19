## Why

Monthly passes are renewed by hand: the front desk reads the "pass expiring" notification (`notify_expiring_monthly_passes`, admins only, three days before, non-auto-renew passes only), calls the customer, and collects cash. Passes with `auto_renew = true` are renewed by `renew_monthly_passes` only AFTER they end and the new pass starts with a pending cash charge that an admin must collect (`register_pass_payment`). Customers forget, the pass lapses, and revenue is collected late or never. A WhatsApp reminder with a payment link lets the customer renew from the phone before the pass ends.

## What Changes

- **Reminder cadence (works without payment keys).** A scheduled function `queue_pass_renewal_reminders()` queues WhatsApp messages to the vehicle owner's phone at a per-lot cadence (default 7, 3 and 1 days before the pass ends; `parking_settings.pass_renewal_cadence`), exactly once per cadence window (`whatsapp_messages.dedupe_key`). Without payment links the message is the existing `pass_expiry` template (reminder only).
- **Payment link (needs `add-online-payments`).** When the lot turns on `pass_renewal_payment_links`, an open renewal offer (`pass_renewal_offers`, unguessable token, planned period and amount) is created per pass and the message uses the new template `pass_renewal_link`, whose URL button opens the public page `/renew?t=<token>`. The page asks the new Edge Function `pass-renewal-intent` for a Wompi checkout; payment is confirmed ONLY by the existing signed `payment-webhook` through `apply_payment_event`, which now settles `kind = 'pass'` intents.
- **Settlement.** An approved renewal creates the linked next pass (same vehicle, lot, amount, `auto_renew`, `renewed_from_id`), marks its `monthly_pass_payments` row `paid` with method `online`, notifies the lot's members, and is idempotent (never two renewals for one pass, never a double charge with `renew_monthly_passes`).
- **Admin UI.** Settings page section for the three new settings; the monthly passes tile shows "Link sent" / "Renewed online" and a manual "Send renewal link" action (`send_pass_renewal_link`).
- **Degradation.** No WhatsApp credentials: messages stay `pending`, in-app notifications keep working. No `WOMPI_*` keys or `online_payments_enabled` off: the link switch cannot be turned on; with keys removed later the public page shows "pay at the desk". Flag `pass_renewal_enabled` off (default): nothing is queued.
- **BREAKING:** none. `renew_monthly_passes`, `register_pass_payment` and `notify_expiring_monthly_passes` keep their signatures; `monthly_pass_payments.payment_method` accepts one more value (`online`).

## Capabilities

### New Capabilities

- `pass-renewal-payments`: reminder cadence, renewal offers and tokens, the public renewal page, intent creation for a renewal, settlement of an approved renewal, manual send, and degradation without keys.

### Modified Capabilities

- `monthly-passes`: an auto-renewing pass renewed early by an online payment is not renewed a second time by the expiry job, and its earlier pass is deactivated once it has ended.

## Impact

- **Depends on** `add-online-payments` (tables `payment_intents`, `payment_events`, functions `apply_payment_event`, `settle_payment_intent`, `report_online_payments`, the gateway port, `payment-webhook`, `payments-reconcile`, env `WOMPI_*`, `PAYMENT_REDIRECT_BASE_URL`, setting `online_payments_enabled`). It must be implemented after it. Reminder-only behaviour has no hard dependency on payments but ships in the same change.
- **Database (2 migrations, next free numbers, in this order):** `<NEXT>_pass_renewal_schema.sql`, `<NEXT>_pass_renewal_rpcs.sql`.
  - New table `pass_renewal_offers`; new columns `parking_settings.pass_renewal_enabled`, `pass_renewal_payment_links`, `pass_renewal_cadence`; `whatsapp_messages.button_param`, `whatsapp_messages.dedupe_key`; `payment_intents.pass_renewal_offer_id` and widened `kind` / target checks; `monthly_pass_payments.payment_method` check widened.
  - New RPCs `queue_pass_renewal_reminders`, `send_pass_renewal_link`, `public_pass_renewal`, `create_pass_renewal_intent`, `settle_pass_renewal`, `queue_whatsapp_message` (internal); re-declared `settle_payment_intent` and `report_online_payments` (same signatures).
- **Edge Functions:** new `pass-renewal-intent`; `whatsapp-dispatch` gains the `pass_renewal_link` template and the URL-button component (the file is currently untracked in git: see tasks); `supabase/jobs.sh` and `supabase/notifications-cron.sh` call `queue_pass_renewal_reminders`.
- **Env keys:** `WHATSAPP_TEMPLATE_PASS_RENEWAL` (default `pass_renewal_link`). The payment keys are those of `add-online-payments`.
- **Flutter:** new feature `lib/features/pass_renewal/`; changes in `monthly_passes`, `settings`, `notifications`, `lib/app/router`, `lib/app/di`, `lib/core/network/supabase_error_mapper.dart`, `lib/core/l10n/failure_messages.dart`, ARB files.
- **Docs:** `CHANGELOG.md`, `docs/project-overview.md`, `docs/database.md`, `docs/agent-memory.md`, `.env.example`, `docs/environment-guide.en.md` / `.md` (WhatsApp template list).

## Non-Goals

- Card-on-file / recurring charges (each renewal is a new customer-approved payment; Wompi tokenised recurring payments are out of scope).
- Retroactive coverage for the days between expiry and a late payment (see Open Questions).
- Changing pass prices (the amount is the previous pass's amount, as `renew_monthly_passes` already does).
- SMS or e-mail channels (WhatsApp only; the in-app notification to admins stays).
- Customer self-service to cancel auto-renew from the page.
