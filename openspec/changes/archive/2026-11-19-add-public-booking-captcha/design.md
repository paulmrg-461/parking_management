## Context

`public_create_reservation` (latest body in `0095`) is `security definer` and granted to `anon`, so anything the page can do, `curl` with the anon key can do. A captcha that lives only in the page is decoration: the check has to sit on the server, and the anonymous path has to close when the captcha is demanded.

Postgres cannot ask Cloudflare. The shipped `supabase/postgres:17.6.1.136` image lists `http`, `pg_net` and `pg_cron` in `pg_available_extensions`, but the project installs none of them, `pg_net` is asynchronous (no answer inside the booking transaction), and a synchronous `http` call would put the Turnstile secret in the database and hold the capacity advisory locks while waiting on a third party. The repo already runs Edge Functions with the service-role key for exactly this kind of work (`public-evidence`, `whatsapp-dispatch`).

## Goals / Non-Goals

**Goals:**

- When a lot demands a captcha, no caller holding only the anon key can create a public hold without a Turnstile token verified with the secret.
- A deployment without Turnstile keys behaves as it does today.
- The endpoint is never unlimited: a credential-free ceiling applies with or without the captcha.
- Staff reservations are untouched.

**Non-Goals:**

- Per-IP rate limiting (the gateway does not forward a trustworthy client address to Postgres; a per-lot ceiling needs none).
- Protecting `public_availability`, the lookup or the cancel RPC (read-only or keyed by code + plate + phone).
- A settings-screen toggle for the two new settings (RPC only in this change; see Open Questions).
- Other captcha vendors.

## Decisions

1. **The privilege boundary is a GRANT, not a role read from the JWT.** The booking body moves to `public_create_reservation_verified`, executable by `service_role` only (`revoke ... from public, anon, authenticated`, because Supabase default privileges hand new functions to those roles). The Edge Function holds the service-role key; `anon` cannot execute the function at all. Rejected: one function that inspects `request.jwt.claims ->> 'role'` — it works under PostgREST but depends on a GUC the caller's connection sets, and a grant is checked by Postgres itself.

2. **`public_create_reservation` keeps its exact signature and becomes the gate.** It raises `CaptchaRequiredError` when the lot's `public_booking_captcha` is true, else it calls the verified body (allowed: it is `security definer`). No parameter is added, so there is no second overload for PostgREST to find ambiguous (the trap `agent-memory` records for `save_parking_spot` and `check_in`), old clients keep working, and the existing SQL tests are untouched. Rejected: adding `p_captcha_token` to the RPC — Postgres could not verify it anyway.

3. **Enforcement is a per-lot switch in the database (`parking_settings.public_booking_captcha`, default false).** The database is the only component that can refuse the direct call, and it cannot see whether the function has a secret, so the requirement has to be data. Trade-off: three things must agree for a protected lot — the secret in the function, the site key in the web build, the switch on the lot. Turning the switch on without keys closes online booking for that lot with a clear message (fail closed), which is the safe direction.

4. **The function is inert, never permissive, without a secret.** With no `TURNSTILE_SECRET_KEY` it forwards to the anonymous RPC with the anon key: a lot without the switch books as before, a lot with it is refused by the database. It never calls the verified RPC unverified. A wrong secret or an unreachable Cloudflare is `CaptchaUnavailableError` (503), not a pass.

5. **The client chooses the path by whether it has a token.** No site key (or a platform without the widget) → no token → anonymous RPC, exactly today's request. Site key → widget → token → Edge Function. The page does not need to know the lot's switch, so `public_availability` is not touched.

6. **Throttle: count of `source = 'public'` rows created in the last hour, per lot, inside the verified body.** It counts created rows whatever their status, so book-and-cancel does not reset it; it ignores `source = 'app'`, so the desk is never throttled and never consumes the window. A `pg_advisory_xact_lock(hashtext('public_booking_throttle'), lot)` taken before the capacity locks makes the count exact under concurrency (only this function takes it, so the lock order is fixed). The window is fixed at one hour; the ceiling is the setting (`1..1000`, default 20 — far above a real lot's web bookings per hour, far below what fills a lot). Rejected: a separate counter table (another thing to purge) and a per-phone/plate window (the attacker rotates both).

7. **Turnstile tokens are single use, so the form discards the token after every submit.** Success or failure, the page re-renders a fresh challenge (`KeyedSubtree` + epoch). Expiry and widget errors clear the token and show a message with "Reintentar"; the submit is blocked locally while there is no token, so a customer never sends a request that can only fail.

8. **The widget is injected.** `PublicBookingPage.captchaBuilder` defaults to Turnstile where `dart.library.js_interop` exists and to nothing elsewhere (conditional export, the `web_push` pattern). Widget tests inject a fake with solve/expire/fail buttons; the browser-only file holds no logic beyond script loading and the three callbacks.

9. **Typed errors travel unchanged.** The function answers `{"message": "<Name>Error"}`; the data source turns any such name into `ValidationFailure(code)` and the page localizes it, the same contract the RPC errors already follow. `BookingThrottledError` is HTTP 429 from the function.

## Risks / Trade-offs

- [A lot with keys configured but the switch off is still bookable by direct RPC] → By design: the switch is the enforcement. Documented in `.env.example` and `agent-memory`; the throttle still applies.
- [A real burst of customers hits the ceiling] → Default 20/hour per lot, tunable to 1000; the message tells the customer to call; the desk can still reserve for them.
- [An attacker spends the hourly window to deny web booking] → The damage is bounded to the web channel of one lot for at most an hour and costs the attacker a captcha per hold when the captcha is on. Without it, this is the accepted price of having a ceiling at all.
- [Cloudflare outage blocks protected lots] → Fail closed with a "call the parking lot" message; the admin can turn the switch off with one RPC.
- [The browser widget is not covered by VM widget tests] → Kept logic-free; the form logic is tested through the injected fake, and the function was exercised against a mock `siteverify`.
- [`TURNSTILE_SECRET_KEY` reaches the function only if compose passes it] → Added to the `functions` service environment.

## Migration Plan

1. Apply `0103` (additive columns, new functions; the gate replaces the RPC body in place). Nothing changes for existing lots except the 20/hour ceiling.
2. Restart `functions` so `public-booking` is served.
3. To protect a lot: set `TURNSTILE_SECRET_KEY` in `.env`, restart `functions`, rebuild the web app with `--dart-define=TURNSTILE_SITE_KEY=...`, deploy it, then `select set_public_booking_protection(true, null)` as that lot's admin. Order matters: the switch goes last.
4. Rollback: `select set_public_booking_protection(false, null)` restores anonymous booking immediately; reverting the migration means re-applying the `0095` body.

## Open Questions

- Should the two settings get a section in Ajustes? It needs the `ParkingSettings` entity, DTO and Hive adapter regenerated; left out to keep this change scoped.
