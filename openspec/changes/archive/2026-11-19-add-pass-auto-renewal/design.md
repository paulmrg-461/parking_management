## Context

Verified against the repository on 2026-11-10 (head migration `0102`):

- `monthly_passes`: `id, vehicle_id, start_date, end_date, amount, active, created_at, auto_renew boolean, renewed_from_id bigint unique, auto_renew_payment_method text (cash|card|transfer), lot_id` (`0001`, `0013`, `0016`, `0023`). RLS `passes_read` (`lot_id = current_lot_id()`), `passes_admin_write` (lot admins).
- `monthly_pass_payments`: `id, monthly_pass_id unique, amount > 0, payment_method (cash|card|transfer), status (pending|paid|waived), due_date, paid_at, paid_by, shift_id, lot_id`; one pending row per pass is created by trigger `trg_create_pass_payment` (`create_pass_payment()`, latest `0023`); `register_pass_payment(p_payment_id bigint, p_payment_method text default null)` latest `0073` (admin; cash needs the actor's open shift).
- `renew_monthly_passes()` latest `0073`: renews active `auto_renew` passes with `end_date < lot-local today` that have no child (`renewed_from_id`), calendar-month periods via `pass_period_months(p_start date, p_end date)`, copies the amount, then deactivates the renewed parents.
- `notify_expiring_monthly_passes()` latest `0024`: notification `monthly_pass_expiring` to lot admins, only non-auto-renew passes, `end_date = current_date + 3`.
- `whatsapp_messages(id, user_id, lot_id, to_phone, template, language, params jsonb, status pending|sent|failed, attempts, error, created_at, sent_at)` (`0042`); `enqueue_whatsapp_message(p_to_phone, p_template, p_params default '[]', p_language default 'es')` requires `parking_settings.whatsapp_auto`. `whatsapp-dispatch` (service role) maps `template` to a Meta template through a `TEMPLATES` record, sends `components: [{type:'body', parameters}]`, retries 3 times. The folder `supabase/volumes/functions/whatsapp-dispatch/` is NOT allowlisted in `supabase/.gitignore` (untracked) — a known open item in `docs/agent-memory.md`.
- Vehicle contact: `vehicles.owner_phone varchar(32)` (7 to 15 digits) and `owner_name varchar(120)` (`0041`, `0078`).
- Flutter: `MonthlyPassesCubit` (`lib/features/monthly_passes/application/monthly_passes_cubit.dart`), `monthly_passes_page.dart` `_MonthlyPassTile._notify` (queues `pass_expiry` with params `[plate, Formatters.date(endDate)]` through `CustomerMessageRepository.enqueueWhatsapp` when `whatsappAutoEnabled(context)`, otherwise opens `wa.me`). Passes are an admin-only deferred route (`monthly-passes`).
- From `add-online-payments` (design in `openspec/changes/add-online-payments/design.md`): `payment_intents` (reference, amount, status, gateway ids), `payment_events`, `apply_payment_event(p_gateway, p_event)`, `settle_payment_intent(p_intent_id)` (internal, today only `kind = 'session'`), `report_online_payments`, `PaymentGateway` port, `payment-webhook`, `payments-reconcile`, `parking_settings.online_payments_enabled / online_payment_min_amount`, env `WOMPI_*`, `PAYMENT_REDIRECT_BASE_URL`.

> `public_create_reservation` and other `public_*` RPCs may have changed while this was written. This change does not touch them.

## Goals / Non-Goals

**Goals:** a customer renews a pass from a WhatsApp link before it ends; reminders follow a cadence; confirmation only by the signed webhook; no double renewal; the feature degrades to reminder-only without payment keys.

**Non-Goals:** see `proposal.md`.

## Decisions

1. **Offer, not pre-created pass.** Creating the next pass before payment would let a customer park free from its start date (`has_pass` only reads dates and `active`). An offer row holds the planned period and amount; the pass is created only on approved payment. Rejected: inserting an inactive pass early (it shows up in the list as a deactivated pass and `renew_monthly_passes`' guard `not exists child` would stop auto-renew for unpaid offers).
2. **Token = access key.** 24 random bytes (`encode(gen_random_bytes(24), 'hex')`, 192 bits) in the URL button; the public RPC exposes only a masked plate, period, amount, lot name. No phone, no vehicle id.
3. **Cadence in the lot settings as a validated text** (`'7,3,1'`) instead of an array: Hive/DTO/Dart stay trivial. Rule per pass: with `days_left = end_date - lot_local_today` pick the smallest cadence value `d >= days_left`; send once per `(offer, d)` (`dedupe_key`); passes ended more than 3 days ago get nothing. This makes a late cron run send the nearest missed reminder once instead of a burst.
4. **Two switches plus the global one, same pattern as captcha/WhatsApp:** `pass_renewal_enabled` (reminders), `pass_renewal_payment_links` (link; a CHECK requires `online_payments_enabled` and COP), and `whatsapp_auto` (existing). Keys are not visible to SQL, so with the link switch on and keys missing the page says "pay at the desk" (fail soft).
5. **Idempotent settlement.** `settle_pass_renewal` locks the offer `for update`. Cases: (a) offer open and no child pass -> create the child, mark its payment paid `online`; (b) a child exists with a pending payment (the expiry job ran first) -> mark that payment paid `online`, create nothing; (c) child already paid or offer already paid -> `late_closed` outcome plus `online_payment_review` notification (refund decision is human).
6. **Period of the new pass.** `start = greatest(offer.period_start, lot_local_today)`; `end` keeps the calendar-month rule of `renew_monthly_passes` (`pass_period_months`) else the day count of the previous pass. ASSUMPTION: a customer who pays after expiry is not covered retroactively; the owner must confirm.
7. **Parent deactivation.** `queue_pass_renewal_reminders` also runs `update monthly_passes set active = false where active and end_date < local today and exists (child)`, because `renew_monthly_passes` never revisits a parent that already has a child. It never deactivates a pass whose dates still cover today.
8. **Online money for passes is not cash.** The `monthly_pass_payments` row is paid with `payment_method = 'online'`, `paid_by = null`, `shift_id = null`, so it never enters `shift_totals.pass_cash_sales`/`pass_payments` (those read `shift_id`), but it does appear in `report_revenue.pass_revenue` / `pass_by_payment` (they read `paid_at`) and in `report_online_payments`.
9. **WhatsApp deduplication and a button parameter.** `whatsapp_messages` gains `dedupe_key text` (unique when not null) and `button_param text`. An internal `queue_whatsapp_message` helper inserts `on conflict (dedupe_key) where dedupe_key is not null do nothing`. The dispatcher appends `{type:'button', sub_type:'url', index:'0', parameters:[{type:'text', text: button_param}]}` when the row has `button_param`; the fixed base URL lives in the approved Meta template, not in our code.
10. **No overloads.** All new functions are new names; `settle_payment_intent` and `report_online_payments` are re-declared with the exact signatures from `add-online-payments`.

## Data model

### `<NEXT>_pass_renewal_schema.sql`

```sql
alter table public.parking_settings
    add column if not exists pass_renewal_enabled boolean not null default false,
    add column if not exists pass_renewal_payment_links boolean not null default false,
    add column if not exists pass_renewal_cadence text not null default '7,3,1';

alter table public.parking_settings
    drop constraint if exists parking_settings_pass_renewal_check;
alter table public.parking_settings
    add constraint parking_settings_pass_renewal_check check (
        pass_renewal_cadence ~ '^([0-9]|[12][0-9]|30)(,([0-9]|[12][0-9]|30)){0,4}$'
        and (not pass_renewal_payment_links
             or (online_payments_enabled and currency = 'COP'))
    );

alter table public.whatsapp_messages
    add column if not exists button_param text,
    add column if not exists dedupe_key text;
create unique index if not exists uq_whatsapp_dedupe
    on public.whatsapp_messages(dedupe_key) where dedupe_key is not null;

alter table public.monthly_pass_payments
    drop constraint if exists monthly_pass_payments_payment_method_check;
alter table public.monthly_pass_payments
    add constraint monthly_pass_payments_payment_method_check
    check (payment_method in ('cash','card','transfer','online'));

create table if not exists public.pass_renewal_offers (
    id                 bigserial primary key,
    lot_id             integer     not null references public.parking_lots(id),
    monthly_pass_id    bigint      not null references public.monthly_passes(id) on delete cascade,
    token              text        not null unique,
    period_start       date        not null,
    period_end         date        not null,
    amount             integer     not null check (amount > 0),
    status             text        not null default 'open'
        check (status in ('open','paid','expired','cancelled')),
    expires_at         timestamptz not null,
    reminders_sent     integer     not null default 0,
    last_reminder_at   timestamptz,
    paid_at            timestamptz,
    renewal_pass_id    bigint      references public.monthly_passes(id),
    created_at         timestamptz not null default now(),
    check (period_end > period_start)
);
create unique index if not exists uq_pass_renewal_open
    on public.pass_renewal_offers(monthly_pass_id) where status = 'open';
create index if not exists ix_pass_renewal_lot on public.pass_renewal_offers(lot_id, created_at desc);

alter table public.pass_renewal_offers enable row level security;
grant select on public.pass_renewal_offers to authenticated;
drop policy if exists pass_renewal_offers_admin_read on public.pass_renewal_offers;
create policy pass_renewal_offers_admin_read on public.pass_renewal_offers
    for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

-- Widen the intents table created by add-online-payments.
alter table public.payment_intents
    add column if not exists pass_renewal_offer_id bigint references public.pass_renewal_offers(id);
alter table public.payment_intents drop constraint if exists payment_intents_kind_check;
alter table public.payment_intents add constraint payment_intents_kind_check
    check (kind in ('session','pass'));
alter table public.payment_intents drop constraint if exists payment_intents_target_check;
alter table public.payment_intents add constraint payment_intents_target_check check (
    (kind = 'session' and session_id is not null and pass_renewal_offer_id is null)
    or (kind = 'pass' and pass_renewal_offer_id is not null and session_id is null)
);
```

The checks in `payment_intents` were created inline by `add-online-payments` (`payment_intents_kind_check` is the Postgres default name for the inline column check, `payment_intents_target_check` is named explicitly). Verify both names with `\d public.payment_intents` before applying.

### `<NEXT>_pass_renewal_rpcs.sql`

All functions `language plpgsql`, `security definer`, `set search_path = public`. Service-only and cron functions end with `revoke all ... from public, anon, authenticated;` (+ `grant ... to service_role` where listed).

| Function | Signature | Grant | Returns |
|---|---|---|---|
| `queue_whatsapp_message` | `(p_lot_id integer, p_phone text, p_template text, p_params jsonb, p_button_param text, p_dedupe_key text)` | none (internal) | `boolean` (true = inserted) |
| `queue_pass_renewal_reminders` | `()` | none (cron as superuser, like `notify_overstays`' siblings in `jobs.sh`) | `integer` messages queued |
| `send_pass_renewal_link` | `(p_pass_id bigint)` | `authenticated` | `{offer_id, status, queued boolean}` |
| `public_pass_renewal` | `(p_token text)` | `anon, authenticated` | see below, or `null` |
| `create_pass_renewal_intent` | `(p_token text)` | `service_role` | `{intent_id, reference, amount, currency, status, expires_at}` |
| `settle_pass_renewal` | `(p_intent_id bigint)` | none (internal, called by `settle_payment_intent`) | `{kind:'pass', applied boolean, renewal_pass_id bigint, outcome text}` |
| `settle_payment_intent` | `(p_intent_id bigint)` | none | re-declared: `kind = 'session'` behaviour copied unchanged from `add-online-payments`, `kind = 'pass'` calls `settle_pass_renewal` |
| `report_online_payments` | `(p_start_date date, p_end_date date)` | `authenticated` | re-declared: items gain `kind text`, `pass_id bigint`; plate comes from the session or the pass's vehicle; `ticket_number` is null for passes |

Behaviour:

- `queue_pass_renewal_reminders` (run order inside one call): (1) expire offers (`open` and `expires_at < now()` -> `expired`); (2) deactivate ended parents that already have a child (decision 7); (3) for each lot with `pass_renewal_enabled and whatsapp_auto`, for each active pass of the lot with `end_date between today - 3 and today + 30`, a vehicle `owner_phone` with 7 to 15 digits, and no child pass (`renewed_from_id`) and no pending/approved renewal: compute `days_left` and the target cadence value `d` (decision 3). If `pass_renewal_payment_links` is true create or refresh the open offer (period = `end + 1` through the month-aware end, amount = `monthly_passes.amount`, `expires_at = (end_date + 8)::timestamp at time zone tz`) and queue template `pass_renewal_link` with params `[owner_name or 'cliente', plate, 'DD/MM/YYYY' of end_date, public.format_money(amount, currency)]`, `p_button_param = token`, dedupe key `'pass_renewal:' || offer_id || ':' || d`; otherwise queue `pass_expiry` with params `[plate, 'DD/MM/YYYY']` and dedupe key `'pass_reminder:' || pass_id || ':' || end_date || ':' || d`. Phone normalisation: digits only; if 10 digits starting with `3` prefix `57` (ASSUMPTION: Colombian numbers). Update `reminders_sent`, `last_reminder_at` only when the insert happened. Uses the lot timezone (`business_timezone`) for "today"; never `current_lot_id()`.
- `send_pass_renewal_link(p_pass_id)`: `require_lot_admin()`; errors `PassNotFoundError` (unknown pass or other lot), `PassRenewalDisabledError` (`pass_renewal_enabled` and `pass_renewal_payment_links` both required), `WhatsappDisabledError` (existing name), `MissingOwnerPhoneError`, `PassAlreadyRenewedError` (child exists). Creates or reuses the open offer and queues one message with dedupe key `'pass_renewal_manual:' || offer_id || ':' || local_date` (one manual send per day).
- `public_pass_renewal(p_token)`: returns `{status, lot_name, plate_masked, period_start, period_end, amount, currency, expires_at, payment_links_enabled, renewal_period_start, renewal_period_end}` or `null` for an unknown token. `plate_masked = left(plate, 3) || repeat('*', greatest(length(plate) - 3, 0))`. `status` is the offer status, plus the value `paid` carrying the new period when settled.
- `create_pass_renewal_intent(p_token)`: errors `PassRenewalNotFoundError` (unknown token), `PassRenewalPaidError` (offer `paid`), `PassRenewalExpiredError` (`expired`/`cancelled` or past `expires_at`), `OnlinePaymentsDisabledError` (switches), `AmountTooLowError`, `PaymentThrottledError` (5 intents per offer in an hour). Advisory lock `hashtext('pass_intent')` on the offer id; reuses a pending intent with the same amount; otherwise expires pending ones and inserts `kind = 'pass'` with the same reference format and 30-minute expiry as `add-online-payments`.
- `settle_pass_renewal`: decision 5. The child insert sets `lot_id`, `auto_renew = parent.auto_renew`, `auto_renew_payment_method = parent.auto_renew_payment_method`, `active = true`; the existing trigger then inserts the pending payment, which is updated to `status = 'paid', payment_method = 'online', paid_at = now(), paid_by = null`. Offer -> `paid`, `paid_at`, `renewal_pass_id`. Notifications to active lot members: `pass_renewal_paid` (title "Mensualidad renovada en línea", body plate and period, `data.monthly_pass_id`), `dedupe_key = 'pass_renewal_paid:' || offer_id || ':user:' || user_id`; review cases use `online_payment_review`. `now()` is constant inside the transaction, so ordering assertions use explicit timestamps.

## Edge Functions

- `pass-renewal-intent`: `POST /functions/v1/pass-renewal-intent`, headers `apikey`/`Authorization` anon, body `{"token": "<48 hex chars>"}`. Success `200 {"intent_id", "reference", "amount", "currency", "checkout_url", "expires_at"}`. Errors `{"message": "<Name>Error"}`: `400 InvalidLinkError` (token not 48 hex chars), `404 PassRenewalNotFoundError`, `409 PassRenewalPaidError | PassRenewalExpiredError | OnlinePaymentsDisabledError`, `422 AmountTooLowError`, `429 PaymentThrottledError`, `503 PaymentsNotConfiguredError`. Uses `../_shared/payment_gateway.ts` / `wompi_gateway.ts` / `http.ts` from `add-online-payments`; redirect URL `${PAYMENT_REDIRECT_BASE_URL}/renew?t=<token>`. Allowlist the folder in `supabase/.gitignore`.
- `payment-webhook` and `payments-reconcile`: unchanged code; they already call `apply_payment_event`, which now settles `pass` intents through `settle_payment_intent`.
- `whatsapp-dispatch`: add `pass_renewal_link: Deno.env.get('WHATSAPP_TEMPLATE_PASS_RENEWAL') ?? 'pass_renewal_link'` to `TEMPLATES` (body params: name, plate, date, amount; URL button parameter: token), include `button_param` in the queue `select`, add the button component when present, document the env var in the header comment, pass `WHATSAPP_TEMPLATE_PASS_RENEWAL` in `docker-compose.yml`, and add `!volumes/functions/whatsapp-dispatch/` plus the `index.ts` allowlist lines to `supabase/.gitignore` so the function that sends the links is versioned.

Meta template the owner must create and get approved (assumption: category UTILITY): name `pass_renewal_link`, language `es`, body "Hola {{1}}, la mensualidad del vehículo {{2}} vence el {{3}}. Renuévala por {{4}} aquí:" and a URL button `https://<APP_URL>/renew?t={{1}}`.

## Sequences

1. Cron (`jobs.sh`, every 5 minutes): `queue_pass_renewal_reminders` -> rows in `whatsapp_messages` -> `whatsapp-dispatch` sends them.
2. Customer taps the button -> `/renew?t=<token>` -> `public_pass_renewal` -> "Pagar y renovar" -> `pass-renewal-intent` -> Wompi -> `payment-webhook` -> `apply_payment_event` -> `settle_payment_intent` -> `settle_pass_renewal` -> customer returns to `/renew?t=<token>`, page polls `public_pass_renewal` (3 s, 180 s) until `paid`.
3. Admin presses "Send renewal link" on a pass tile -> `send_pass_renewal_link`.

## Flutter

New feature `lib/features/pass_renewal/` (public page):

```
domain/entities/pass_renewal_offer.dart     // PassRenewalOffer{status:PassRenewalStatus, lotName:String, plateMasked:String, periodStart:DateTime, periodEnd:DateTime, amount:int, currency:String, expiresAt:DateTime, paymentLinksEnabled:bool}; enum PassRenewalStatus{open,paid,expired,cancelled}
domain/entities/pass_renewal_checkout.dart  // PassRenewalCheckout{checkoutUrl:String, reference:String, expiresAt:DateTime}
domain/repositories/pass_renewal_repository.dart // load(String token) -> PassRenewalOffer?; startPayment(String token) -> PassRenewalCheckout
application/pass_renewal_cubit.dart         // ResilientCubit<PassRenewalState>
infrastructure/pass_renewal_remote_data_source.dart  // rpc('public_pass_renewal'), functions.invoke('pass-renewal-intent')
infrastructure/pass_renewal_repository_impl.dart
presentation/pass_renewal_page.dart
```

`PassRenewalState` (sealed, Equatable): `PassRenewalInitial`, `PassRenewalLoading` (skeleton of the summary card), `PassRenewalReady` (`offer`, `submission:Submission`), `PassRenewalUnavailable` (empty state: unknown token or expired, with the lot contact hint), `PassRenewalFailure` (error + Retry). Methods `load(token)`, `pay(token)` (returns the checkout URL via `SubmissionSucceeded`), `track(token)` (poll 3 s up to 180 s until `paid`).

Existing code changed:

- `lib/app/router/route_access.dart`: `const renewPath = '/renew';` added to the public paths in `authRedirect` (next to `evidencePath`); `operatorRoutes` unchanged. `lib/app/router/app_router.dart`: `GoRoute(path: renewPath, builder: ... BlocProvider<PassRenewalCubit>(create: serviceLocator<PassRenewalCubit>()) ... PassRenewalPage(token: state.uri.queryParameters['t']))`. `lib/app/di/modules/pass_renewal_module.dart` (NEW) registered in `registerAllModules`.
- `settings`: `ParkingSettings`/`ParkingSettingsDto` gain `passRenewalEnabled:bool=false`, `passRenewalPaymentLinks:bool=false`, `passRenewalCadence:String='7,3,1'`; regenerate with `dart run build_runner build --delete-conflicting-outputs`; `settings_page.dart` section "Renovación de mensualidades" (switch, link switch disabled unless `onlinePaymentsEnabled` and COP, cadence field validated by regex and 5 values max).
- `monthly_passes`: `PassRenewalOfferSummary{monthlyPassId, status, remindersSent, lastReminderAt}` entity; `MonthlyPassRepository.renewalOffers()` (online only, reads `pass_renewal_offers`, returns `[]` offline) and `sendRenewalLink(int passId)` (calls `send_pass_renewal_link`; forbidden offline: `NetworkFailure`, never queued); `MonthlyPassesLoaded.offers: Map<int, PassRenewalOfferSummary>`; tile chip "Link sent"/"Renewed online" and a "Send renewal link" action visible only to admins when `passRenewalPaymentLinks` is on and the vehicle has `ownerPhone`; `monthly_pass_dialog.dart` unchanged.
- `notifications`: `notification_routes.dart` maps `pass_renewal_paid` to `/monthly-passes`; `notifications_page.dart` adds label and icon.
- Errors: add `PassRenewalNotFoundError`, `PassRenewalPaidError`, `PassRenewalExpiredError`, `PassRenewalDisabledError`, `MissingOwnerPhoneError`, `PassAlreadyRenewedError`, `PassNotFoundError` to `_domainCodes` in `lib/core/network/supabase_error_mapper.dart` and to `FailureMessages._byCode`.

### New l10n keys (ES / EN)

| Key | ES | EN |
|---|---|---|
| `passRenewalTitle` | Renueva tu mensualidad | Renew your monthly pass |
| `passRenewalPlate` | Vehículo {plate} | Vehicle {plate} |
| `passRenewalPeriod` | Nuevo periodo: {from} a {to} | New period: {from} to {to} |
| `passRenewalAmount` | Valor | Amount |
| `passRenewalPay` | Pagar y renovar | Pay and renew |
| `passRenewalChecking` | Confirmando tu pago… | Confirming your payment… |
| `passRenewalPaid` | Mensualidad renovada hasta el {date}. | Pass renewed until {date}. |
| `passRenewalUnavailable` | Este enlace ya no está disponible. Comunícate con el parqueadero. | This link is no longer available. Contact the parking lot. |
| `passRenewalPayAtDesk` | El pago en línea no está disponible por ahora; renueva en caja. | Online payment is unavailable right now; renew at the desk. |
| `passRenewalLinkSent` | Enlace enviado | Link sent |
| `passRenewalRenewedOnline` | Renovada en línea | Renewed online |
| `passRenewalSendLink` | Enviar enlace de renovación | Send renewal link |
| `passRenewalLinkQueued` | Enlace en cola de WhatsApp | Link queued on WhatsApp |
| `settingsPassRenewal` | Renovación de mensualidades | Pass renewal |
| `settingsPassRenewalHint` | Envía recordatorios por WhatsApp antes de que venza la mensualidad. | Sends WhatsApp reminders before a pass ends. |
| `settingsPassRenewalLinks` | Incluir enlace de pago | Include payment link |
| `settingsPassRenewalLinksHint` | Requiere pagos en línea activos y credenciales Wompi. | Requires online payments and Wompi credentials. |
| `settingsPassRenewalCadence` | Días de aviso (ej. 7,3,1) | Reminder days (e.g. 7,3,1) |
| `settingsPassRenewalCadenceInvalid` | Usa hasta 5 números entre 0 y 30 separados por comas | Use up to 5 numbers from 0 to 30 separated by commas |
| `notifTypePassRenewalPaid` | Mensualidad renovada en línea | Pass renewed online |
| `errorPassRenewalNotFound` | Enlace de renovación no válido | Invalid renewal link |
| `errorPassRenewalPaid` | Esta mensualidad ya fue renovada | This pass was already renewed |
| `errorPassRenewalExpired` | El enlace de renovación venció | The renewal link has expired |
| `errorPassRenewalDisabled` | La renovación en línea no está activa en esta sede | Online renewal is not enabled at this site |
| `errorMissingOwnerPhone` | El vehículo no tiene teléfono del propietario | The vehicle has no owner phone |
| `errorPassAlreadyRenewed` | La mensualidad ya tiene una renovación | The pass already has a renewal |
| `errorPassNotFound` | Mensualidad no encontrada | Pass not found |

### Offline behaviour (AGENTS section 5)

The public page and every renewal action need the network; nothing is queued in the Hive outbox. `sendRenewalLink` is an online-only admin action (offline -> localized `NetworkFailure` snack). Money collection through the webhook is server side and never depends on the client being online. The existing offline-first pass list (Hive) keeps working; `offers` is `{}` while offline.

## Security analysis

| Actor | Can |
|---|---|
| `anon` | `public_pass_renewal(token)` (masked data only) and `pass-renewal-intent` (token-keyed, throttled). Cannot call `create_pass_renewal_intent`, `settle_*`, `queue_*`. |
| operator | Nothing new (passes are admin routes; `pass_renewal_offers` is not readable). |
| lot admin | Read offers of the active lot; `send_pass_renewal_link`; edit the three settings. |
| service role | `create_pass_renewal_intent`, webhook-driven settlement. |

- Lot isolation: offers and intents carry `lot_id` copied from the pass; `send_pass_renewal_link` and the offers policy use `require_lot_admin()` / `current_lot_id()`.
- A forged or replayed webhook cannot renew a pass (checksum + unique event key from `add-online-payments`); an altered amount fails the intent amount comparison.
- Token guessing is infeasible (192 bits); the page leaks only the masked plate, dates, amount, lot name.
- WhatsApp content never contains the phone of someone else; phones are read server-side from `vehicles.owner_phone`.

## Risks / Trade-offs

- [Customer pays after the pass lapsed] -> period starts today (decision 6); owner decision.
- [Meta template not approved] -> messages stay `pending`/`failed` visible in `/diagnostics`; reminders for in-app admins continue.
- [Two renewals racing (expiry job vs payment)] -> offer lock + child-pass checks (decision 5) and `renewed_from_id unique`.
- [Reminder fatigue] -> cadence is per lot and one message per window.
- [Cadence parsed from text] -> validated by a CHECK regex; parsing happens in SQL only.

## Migration Plan

1. Implement and merge `add-online-payments` first. Apply the two migrations (additive; all flags default off).
2. Version and deploy `whatsapp-dispatch` (now allowlisted) and `pass-renewal-intent`; restart `functions`.
3. Create and approve the Meta template; set `WHATSAPP_TEMPLATE_PASS_RENEWAL` if the name differs.
4. Per lot: turn on `pass_renewal_enabled` (reminders), later `pass_renewal_payment_links`.
5. Rollback: switch both flags off; reverting means dropping the new objects after confirming no `paid` offer exists.

## Open Questions (owner must answer)

1. Retroactive coverage when a customer pays after expiry (this design: no; period starts today).
2. Default cadence (7, 3, 1 days) and whether a post-expiry nudge is wanted.
3. Meta template wording and category approval; will the owner provide the button base URL (`APP_URL`)?
4. Should passes with `auto_renew = true` keep the expiry-job renewal with a pending cash charge when the customer never pays (current behaviour kept)?
5. Is the price of the next pass always the previous amount, or should it follow the category's monthly tariff?
6. Phone normalisation: confirm that 10-digit numbers starting with 3 are Colombian mobiles.
