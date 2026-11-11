## 1. Database: throttle and captcha gate

- [x] 1.1 Write SQL regression tests first in `supabase/tests/rpc_test.sql`: Success (defaults; anon books under the ceiling; service role books through the verified RPC), Failure (third hold of the hour → `BookingThrottledError`; cancelled holds still count; limit `0` rejected), Security (anon and authenticated cannot execute the verified RPC; direct call refused with `CaptchaRequiredError` when the lot demands it; operator cannot change the protection), lot isolation (lot 2 books while lot 1 is throttled or gated)
- [x] 1.2 Add `supabase/migrations/0103_public_booking_protection.sql`: `public_booking_captcha`, `public_booking_hourly_limit` (+ check `1..1000`), partial index on public holds by `(lot_id, created_at)`
- [x] 1.3 Move the booking body to `public_create_reservation_verified` (service_role only) with the hourly ceiling under a per-lot advisory lock
- [x] 1.4 Re-declare `public_create_reservation` with the same signature as the anonymous gate
- [x] 1.5 Add `set_public_booking_protection(p_captcha, p_hourly_limit)` for lot admins
- [x] 1.6 Run `sh supabase/tests/run.sh` against a throwaway database

## 2. Edge Function

- [x] 2.1 Add `supabase/volumes/functions/public-booking/index.ts`: verify the Turnstile token, call the verified RPC with the service role, pass typed errors through, forward as anon when no secret is configured
- [x] 2.2 Pass `TURNSTILE_SECRET_KEY` to the `functions` service and allowlist the function in `supabase/.gitignore`
- [x] 2.3 Exercise the function against a mock `siteverify` and a mock PostgREST (valid, missing, rejected, reused token; outage; throttle; no secret)

## 3. Flutter: repository and cubit

- [x] 3.1 Write tests first: data source (token → Edge Function body; typed errors from RPC and function; untyped 503 → `ServerFailure`), cubit (token forwarded; throttled; rejected captcha never confirms)
- [x] 3.2 Add `captchaToken` to `PublicBookingRepository.reserve`, the data source, the repository impl and `FakePublicBookingRepository`
- [x] 3.3 Add `captchaToken` to `PublicBookingCubit.submit`
- [x] 3.4 Add `AppConfig.turnstileSiteKey` (`TURNSTILE_SITE_KEY`) and pass it from the `/reserve` route

## 4. Flutter: booking form

- [x] 4.1 Write page tests first: no site key → no captcha; solved token travels; no token → no request; expired → message + retry; widget error → message + retry; server rejection discards the token; throttled and captcha-required messages; site key on a platform without the widget books directly
- [x] 4.2 Add `presentation/captcha/`: `CaptchaRequest`/`CaptchaBuilder`, `BookingCaptchaField`, Turnstile web view (skeleton while the script loads) and the non-web stub behind a conditional export
- [x] 4.3 Wire the field into `PublicBookingPage` (token state, single-use reset, local block without a token) and map the new error codes
- [x] 4.4 Add ES/EN strings and regenerate l10n

## 5. Docs and verification

- [x] 5.1 Update `CHANGELOG.md`, `docs/project-overview.md`, `.env.example` and `docs/agent-memory.md`
- [x] 5.2 `flutter analyze`, `flutter test --coverage`, `dart run tool/check_coverage.dart`, `flutter build web --release`
- [ ] 5.3 Smoke the real widget in a browser with Cloudflare's test keys against a stack that has `0103` applied (not done in this change: the running dev stack was off limits)
