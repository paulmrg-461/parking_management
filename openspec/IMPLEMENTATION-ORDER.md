# Implementation order and merge protocol

This file is the canonical sequence for the changes in this folder. A proposal
that says "global order" refers to this list. Migration numbers are always
`<NEXT>` at implementation time (`supabase/migrations/0101`, `0103` and the
rest below are already applied on `feature/supabase`), but the **relative**
order matters: several changes re-declare the same function, and applying them
out of order silently reverts the previous body.

## Waves

| Wave | Changes | Why now |
| --- | --- | --- |
| 0 (done) | `add-parking-settings`, `add-public-booking-captcha` | Already merged; the later public-page changes build on them. |
| 1 — no keys, no hardware | `add-offline-conflict-resolution`, `add-period-comparison-reports`, `add-booking-waitlist`, `add-occupancy-forecast`, `add-cash-anomaly-detection` | Pure SQL + Flutter. They close limitations already written in `docs/project-overview.md` §8. |
| 2 — AI | `add-report-assistant` → `add-ai-damage-comparison` | The second imports `_shared/ai/*` and `ai_features` from the first. |
| 3 — hardware | `add-device-gateway` → `add-lpr-camera-gate` → `add-barrier-control` and `add-bay-sensors` | The gateway ships the registry, key auth, replay protection and the route table the other three extend. `edge/common/device_core` is created by whichever firmware change lands first. |
| 4 — money | `add-online-payments` → `add-pass-auto-renewal` → `add-merchant-validations` → `add-loyalty-rewards` and `add-dynamic-pricing` (either order) | Pass renewal consumes the intent table and webhook; merchant benefits must be applied after the online split exists so `fare_quote` composes both. |
| 5 — legal | `add-electronic-invoicing` | Blocked on the accountant confirming the `ASSUMPTION` rules; it consumes the payment split of wave 4. |

Within a wave any order works **unless** the merge table below says otherwise.

## Re-declared functions and files (merge protocol)

Several changes use `create or replace` on the same function or append to the
same file. The rule is: **the later change re-applies the earlier change's
keys/values, never drops them**, and its first task verifies that the previous
one is already merged (`rg` for a symbol it introduced). A reviewer must diff
the new body against the previous migration, not just against the function it
clones.

| Object | Changes that touch it | Protocol |
| --- | --- | --- |
| `public.check_out` | `add-online-payments`, `add-merchant-validations` | Online payments first. Merchant validation then re-declares it on top of the online body: the amount owed is `gross − automatic adjustments − discount`, and the online part is still deducted for the desk balance. |
| `public.fare_quote`, `fare_pricing_step`, `fare_reward_step` | `add-merchant-validations` (creates `fare_quote` and the two no-op hooks), `add-dynamic-pricing` (replaces `fare_pricing_step`), `add-loyalty-rewards` (replaces `fare_reward_step`) | Merchants first. Pricing and loyalty replace only their own hook and never re-declare `fare_quote`. |
| `public.check_out_preview` | `add-online-payments`, `add-merchant-validations` | Same as `check_out`: the preview must list the online paid amount **and** the adjustment lines. |
| `public.public_session_summary` | `add-online-payments`, `add-merchant-validations` | Same order; the JSON keeps `online_paid_amount` and adds `adjustments[]`. |
| `public.vehicle_history` | `add-merchant-validations` | Re-declares the latest body only (no other change touches it). |
| `public.report_reservations` | `add-booking-waitlist` | Re-declares the latest body (from wave 0/1) and only appends waitlist counters. |
| `public.public_availability` | `add-occupancy-forecast`, `add-dynamic-pricing` | Renames the latest body to `public_availability_base` and wraps it; it never copies the body, so wave-1 edits are safe. Pricing adds the price fields: if the forecast landed first, edit `public_availability_base`; otherwise edit the current body and the forecast's first task renames that body. |
| `public.create_reservation` / `public_create_reservation` | `add-booking-waitlist` (offers), `add-occupancy-forecast` (none) | Offers call `reservation_capacity_check`; they do not re-declare the create RPC. |
| `supabase/volumes/functions/whatsapp-dispatch/index.ts` | `add-pass-auto-renewal`, `add-booking-waitlist`, `add-lpr-camera-gate` | Each adds one entry to `TEMPLATES` and the matching env key; the later change keeps the earlier entries. |
| `supabase/jobs.sh` / `supabase/notifications-cron.sh` | every change that schedules a job | Append one `run` line per function; never reorder or rewrite the list. Restart `supabase-jobs` after editing. |
| `lib/app/di/injection.dart`, `lib/app/router/app_router.dart`, `lib/app/shell/app_destinations.dart` | most Flutter changes | Add the import, the registration/route/destination; do not touch unrelated lines. |
| `docs/agent-memory.md`, `CHANGELOG.md`, `docs/database.md` | every change | Append a section/bullet; the implementation notes of a change are added on top of the previous one. |

## Definition of done (same for every change)

1. `flutter analyze` — 0 errors, 0 warnings.
2. `flutter test --coverage` + `dart run tool/check_coverage.dart` — green, floors respected.
3. `sh supabase/tests/run.sh` — green (every change adds its named cases).
4. `flutter build web --release --no-web-resources-cdn ...` and, when the change touches Dart, `flutter build apk --debug ...`.
5. `CHANGELOG.md`, `docs/database.md`, `docs/project-overview.md`, `docs/agent-memory.md` updated; `openspec archive <change>` after the tasks are green.
6. Conventional commit (`feat:`, `fix:`, `docs:`) pushed to `feature/supabase`.

## Open blockers

- `add-electronic-invoicing`: every DIAN rule is marked `ASSUMPTION`; the owner and the accountant must confirm them and the change must keep `mode = 'off'` until then. It also updates the "no tax engine" line of `openspec/config.yaml`.
- `add-online-payments` and `add-pass-auto-renewal`: need a Wompi account (`WOMPI_*`) and a `PAYMENT_REDIRECT_BASE_URL`; without them the features stay inert by design.
- `add-report-assistant` and `add-ai-damage-comparison`: need `ANTHROPIC_API_KEY`; without it both answer "not configured". Both send a field-allowlisted projection to Anthropic: the owner must sign off on the list before production.
- `add-lpr-camera-gate`, `add-barrier-control`, `add-bay-sensors`: need the hardware and the firmware toolchains (Python for LPR, C++/PlatformIO for barrier and hub, Deno for the gateway). No CI job exists for `edge/**` yet; add one in the first firmware change.
