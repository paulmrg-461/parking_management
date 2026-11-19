## Why

The public booking page (`/reserve?lot=<id>`) creates holds through an RPC the `anon` role can call directly (`public_create_reservation`). Its only abuse controls are business rules (one active hold per plate, two per phone, capacity), so a script that rotates plates and phones can fill a lot's reservable capacity and flood the desk with "Reserva web" alerts and queued WhatsApp messages. `docs/project-overview.md` §7 lists this as a known limitation ("Public booking has no captcha").

## What Changes

- **Throttle (no credentials needed):** a per-lot ceiling on public holds created in the last hour (`parking_settings.public_booking_hourly_limit`, default 20), enforced inside the booking RPC under a per-lot advisory lock. Exceeding it raises `BookingThrottledError`. Staff holds (`create_reservation`, `source = 'app'`) neither count nor are refused.
- **Captcha (operator-provided keys, inert without them):** Cloudflare Turnstile.
  - New Edge Function `public-booking` verifies the token with `TURNSTILE_SECRET_KEY` and then calls `public_create_reservation_verified`, granted to `service_role` only.
  - `public_create_reservation` keeps its name, signature and `anon` grant but becomes a gate: it raises `CaptchaRequiredError` when the lot has `parking_settings.public_booking_captcha = true`, and otherwise runs the shared body.
  - Lot admins switch the requirement and tune the ceiling with `set_public_booking_protection(p_captcha, p_hourly_limit)`.
- **Flutter web:** the booking form renders the Turnstile widget when `--dart-define=TURNSTILE_SITE_KEY` is set, sends the token through the repository (which then books through the Edge Function), and shows localized (ES/EN) messages with retry for "not solved", expired, failed, unavailable and throttled. Mobile/desktop targets compile against a stub and show no widget.

## Capabilities

### New Capabilities

- `public-booking-protection`: the hourly ceiling on public holds, the per-lot captcha requirement, server-side token verification, and how the booking form asks for and recovers the captcha.

### Modified Capabilities

<!-- none: the public booking flow has no spec yet; its existing rules are unchanged -->

## Impact

- **Database:** migration `0103_public_booking_protection.sql` (two `parking_settings` columns + check, a partial index on public holds, `public_create_reservation_verified`, the re-declared gate `public_create_reservation`, `set_public_booking_protection`). Regression tests in `supabase/tests/rpc_test.sql`.
- **Edge Functions:** new `supabase/volumes/functions/public-booking/index.ts`; `supabase/docker-compose.yml` passes `TURNSTILE_SECRET_KEY`; `supabase/.gitignore` allowlists the new function.
- **Flutter:** `AppConfig.turnstileSiteKey`; `PublicBookingRepository.reserve(captchaToken:)` and its data source; `PublicBookingCubit.submit(captchaToken:)`; `presentation/captcha/` (request contract, Turnstile web view + stub, form field); `PublicBookingPage`; router; ARB strings.
- **Config:** `.env.example` gains `TURNSTILE_SECRET_KEY` and documents the `TURNSTILE_SITE_KEY` dart-define.
- **Dependencies:** none added (`web` and `dart:js_interop` are already in use).
- **Breaking:** none. With no keys and the per-lot switch off (default), the page and the RPC behave as before, plus the hourly ceiling.
