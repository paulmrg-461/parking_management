## Why

When every category is full, the public booking page (`/reserve?lot=<id>`) renders `_NoSpace` ("call us") and the customer leaves. When only one category is full its card is disabled. Nothing remembers that the customer wanted a space, so a space freed five minutes later goes to whoever happens to reload the page. The lot loses a booking it could have had, and the desk has no list of people to call.

## What Changes

- **Waitlist entries (NEW table `public.reservation_waitlist`)**: a customer whose category/group is full joins with name, Colombian mobile, plate, category, how long they are willing to wait (`wait_until`) and how long an arrival hold they want once they get a space (`hold_minutes`).
- **Anonymous RPCs (NEW)** in the style of `public_create_reservation`: `public_waitlist_info`, `public_join_waitlist` (gate) + `public_join_waitlist_verified` (service role), `public_waitlist_lookup`, `public_claim_waitlist`, `public_leave_waitlist`. Limits: one active entry per plate and lot, two active entries per phone and lot, `waitlist_max_entries` active entries per lot, and the hourly ceiling and captcha gate introduced by `add-public-booking-captcha`.
- **Offer = a real hold**: when capacity frees, the oldest eligible entry of that vehicle group gets an OFFER, which is a real `category_reservations` row (`source = 'waitlist'`, `status = 'active'`, `reserved_until = now() + waitlist_claim_minutes`) created through `reservation_capacity_check`. Every existing capacity counter already counts it, so an offer cannot overbook by construction.
- **Claim**: code + mobile on the public page (or the desk on the customer's behalf) extends that same hold to `now() + hold_minutes`; from then on it is a normal web reservation (board, reminder, cancel, check-in).
- **Expiry and cascade**: `waitlist_expire()` and `waitlist_dispatch_all()` run from `supabase/jobs.sh` (and `supabase/notifications-cron.sh`); unclaimed offers are expired without grace and the next entry is offered. Capacity-freeing writes (check-out, hold cancelled, bay back in service, capacity raised) also dispatch immediately through non-blocking triggers.
- **Desk**: the reservations board (`/reservations`) gets a "Lista de espera" section (list, call/WhatsApp, claim for the customer, remove) and an admin dialog for the three settings. Lot members receive `waitlist_joined` and `waitlist_offer` notifications like the `public_reservation` alert of `0090`.
- **WhatsApp**: the offer queues a `waitlist_offer` template row in `whatsapp_messages` when `parking_settings.whatsapp_auto` is on; the claim queues the existing `reservation_confirmed`. With `whatsapp_auto` off the join answer says `notify_channel = 'screen'`: the page polls with code + mobile and the desk calls the customer.
- **Reports**: `report_reservations` gains waitlist counters.
- **Flutter**: NEW feature `lib/features/waitlist/` (public card on `/reserve`, desk section on `/reservations`), deep link `/reserve?lot=<id>&waitlist=<code>`, ES/EN strings.

## Capabilities

### New Capabilities

- `booking-waitlist`: joining, limits, FIFO offers backed by real holds, claim, leave, expiry and cascade, desk management, notifications, WhatsApp, reporting and retention of waitlist entries.

### Modified Capabilities

<!-- none: public booking and the reservations board have no archived spec; their existing rules are unchanged except where this change lists a re-declared function -->

## Impact

- **Database** (two migrations, next free numbers at implementation time, in this order): `<NEXT>_booking_waitlist.sql` (settings columns, tables, RLS, indexes, `category_reservations` source/contact constraints, all new RPCs, triggers) and `<NEXT+1>_booking_waitlist_reports.sql` (re-declares only `report_reservations`; a claimed offer flips to `source = 'public'`, so `public_cancel_reservation`, `public_reservation_lookup`, `notify_expiring_reservations` and `cancel_reservation` need no change). Regression tests in `supabase/tests/rpc_test.sql`.
- **Jobs**: `supabase/jobs.sh` and `supabase/notifications-cron.sh` call `waitlist_expire`, `waitlist_dispatch_all`, `purge_waitlist`.
- **Edge Functions**: `supabase/volumes/functions/public-booking/index.ts` accepts `action: 'waitlist_join'`; `supabase/volumes/functions/whatsapp-dispatch/index.ts` maps the `waitlist_offer` template (`WHATSAPP_TEMPLATE_WAITLIST_OFFER`).
- **Flutter**: `lib/features/waitlist/**` (NEW), `lib/features/public_booking/presentation/public_booking_page.dart`, `lib/features/reservations/presentation/reservations_page.dart`, `lib/features/reservations/domain/entities/reservation.dart`, `lib/features/reports/**` (`ReservationReport`), `lib/features/notifications/presentation/notification_routes.dart` and `notifications_page.dart`, `lib/app/router/app_router.dart`, `lib/app/di/injection.dart` + NEW `lib/app/di/modules/waitlist_module.dart`, `lib/core/l10n/failure_messages.dart`, ARB files.
- **Config**: `.env.example` gains `WHATSAPP_TEMPLATE_WAITLIST_OFFER`.
- **Dependencies**: none added.
- **Depends on**: `add-public-booking-captcha` (must be merged first: this change reuses `parking_settings.public_booking_captcha`, `parking_settings.public_booking_hourly_limit`, the advisory lock `hashtext('public_booking_throttle')` and the `public-booking` Edge Function).
- **Order and merge protocol:** wave 1 in `openspec/IMPLEMENTATION-ORDER.md` (it re-declares `report_reservations`).
- **Breaking**: none. `waitlist_enabled` defaults to false; with it off every new RPC refuses with `WaitlistDisabledError` or reports `enabled = false`, the triggers return at once and the page looks as it does today.

## Non-Goals

- Paying or pre-authorising to keep a waitlist place (`add-online-payments` is later in the order).
- Picking a specific bay for a waitlist offer; an offer holds group/category capacity exactly like any hold.
- Blocking regular public bookings or walk-in check-ins while people wait (the queue only gets the space when the dispatch runs; see design §Trade-offs).
- A waitlist for monthly passes.
- SMS or e-mail notification, and WhatsApp free-text messages (Meta only accepts approved templates).
- Editing an entry after joining (the customer leaves and joins again).
- Offline use: every waitlist call is online-only and is never queued in the sync outbox.
