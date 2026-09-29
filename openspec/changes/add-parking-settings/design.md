## Context

The parking lot's identity is hardcoded: thermal receipts print `'PARQUEADERO'` (`lib/features/receipt_printing/infrastructure/esc_pos_generator.dart:19`), PDF receipts do the same (`system_dialog_receipt_printer.dart:36`), the app title comes from a static ARB key, and the login screen renders a generic `Icons.local_parking_rounded`. The backend has no settings table or endpoint (only env-based `core/config.py`), while evidence photos already demonstrate the repo's file-upload pattern (`routes/check_ins.py` + `LocalEvidenceStorage`), and Flutter already has an outbox (`core/sync/`), a generic-but-unused `KeyValueStore`, and admin-by-default routing (`route_access.dart:10`).

Decisions were confirmed with the stakeholder: logo via backend upload + serving endpoint, edits offline-capable through the outbox, and consumption on receipts (thermal + PDF), app chrome (title/login), a floating WhatsApp action, and a contact/about page.

## Goals / Non-Goals

**Goals:**

- Singleton `parking_settings` record (name, address, schedule, phone, website, WhatsApp, logo version) with admin-only writes and public reads.
- Logo upload (multipart, validated) + public byte serving, versioned for cache invalidation.
- Offline-first Flutter access: Hive cache, optimistic saves, outbox replay.
- Branding on receipts (text), app chrome, WhatsApp action, contact page; admin edit form.
- Tests first (Success / Failure / Security) per layer, both backend and Flutter.

**Non-Goals:**

- Raster logo printing on the 80mm thermal receipt (needs 1-bit conversion/sizing; PDF and app chrome carry the logo — follow-up).
- Structured weekly opening-hours engine or using hours to gate business behavior (billing, check-in) — schedule is display-only text.
- Multi-tenant/multiple parking records, per-device settings, or local-only branding.
- Offline logo upload queueing (fields sync offline; logo upload requires connectivity).
- Redesigning platform-level labels (`AndroidManifest` label, bundle names).

## Decisions

1. **Singleton row (`id = 1`) instead of a key/value table.** One form edits one aggregate; a key/value table adds migration and merge complexity with no benefit at this scale. The API is `GET/PATCH /api/settings` (no id in the path).

2. **Schedule is a free-text field (≤120 chars), not a structured model.** Values like `24 horas` or `Lun-Vie 7:00-20:00 / Sab-Dom 8:00-16:00` are display-only (app contact page + receipt footer). A structured weekday model was rejected: it doubles form/schema complexity and nothing in billing depends on it (night tariff has its own config in `tariffs`).

3. **Public reads, admin-only writes.** `GET /api/settings` and `GET /api/settings/logo` require no auth because the login screen must show branding before sign-in (first run has no cache). The table contains only branding fields — no secrets, no operational config — so exposure is equivalent to what receipts print anyway. Writes stay behind `require_admin` (`deps.py:292`); non-admins get 403.

4. **Logo as a stored file + `logo_version` counter, not base64 in the row.** Reuses the evidence-photo pattern: `uploads.py` magic-byte validation (JPEG/PNG, 5 MB), files under a `settings_storage_path` root, DB keeps only metadata. `logo_version` (int, starts 0) is part of the settings record and doubles as the cache key/ETag: Flutter fetches bytes only when `logo_version` differs from its cached one.

5. **One `settings` feature, one repository port, two adapters.** `lib/features/settings/` follows the `categories` template: `ParkingSettings` entity, `ParkingSettingsRepository` port (`load`, `save`, `loadLogo`, `uploadLogo`), `DioParkingSettingsRemoteDataSource` + `HiveParkingSettingsLocalDataSource` + `ParkingSettingsRepositoryImpl`, `ParkingSettingsMutationReplayer`. `save()` = try remote → local upsert; on `NetworkFailure` → optimistic local upsert + `PendingMutation(entityType: settings, operation: update, entityId: "singleton")`. New enum value in `pending_mutation.dart:7` and an entry in `sync_module.dart:24-46` (a missing replayer throws `StateError`, so registration is mandatory). `uploadLogo()` has no offline path by design.

6. **Root-level `BrandingCubit` owns display state.** Registered at the app root (above `MaterialApp`), seeded from Hive at startup, refreshed from the backend when online. Consumers: `onGenerateTitle`, home AppBar, login header/logo, the shell's WhatsApp FAB, contact page. Defaults (l10n `appTitle`, generic icon) apply until the first value arrives, so first-run and offline-cold-start render cleanly.

7. **Print adapters fetch settings themselves; `ReceiptData` stays per-receipt.** `BluetoothPrintScanner.print()` and `SystemDialogReceiptPrinter.printPdf()` receive an injected `ParkingSettingsRepository`, `load()` (cache-first), and pass the identity into the generators (`EscPosGenerator.build(data, settings)` — 2 params, within the Clean Code limit). This keeps every existing call site and test untouched and guarantees printing works offline.

8. **Contacts open via `url_launcher` (new dependency).** `wa.me/<digits>` (non-digits stripped), `tel:`, and `https://` links are opened with `launchUrlString`. This is the only added package; `image_picker` already exists for picking the logo.

9. **Routing: `/settings` admin, `/contact` all roles.** `/settings` is deferred-loaded like `categories` and is admin-only *by default* (`route_access.dart:7`), needing no allowlist entry. `/contact` is read-only and is added to the `operatorRoutes` allowlist plus a `managementDestinations`/home nav entry. Both follow the deferred-import pattern so operators never download the admin form.

10. **Compatibility with an older backend.** A 404/401 on `GET /api/settings` is treated as "unset" (defaults), so the app degrades gracefully until the backend with migration `0012` is deployed.

## Risks / Trade-offs

- [Two admins editing concurrently → last PATCH wins, pull refresh overwrites] → Acceptable for a singleton display record; outbox replays carry the queued payload, and every `load()` re-syncs from the server, so the record self-heals. No version/conflict protocol in v1.
- [Public settings/logo endpoints leak contact data] → By design (branding is public); the table holds only name/address/schedule/phone/website/WhatsApp. If future fields become sensitive, split public vs authenticated reads rather than authing the whole endpoint.
- [Logo upload offline silently missing if queued] → Explicitly not queued; the form shows an error and the cached logo is untouched (spec scenario).
- [Large logo files bloat client cache and receipts] → Server caps at 5 MB and rejects non-images; the PDF embeds the original. Client-side downscaling is deferred (risk accepted; `image` package not yet a direct dependency).
- [New Hive entity requires adapter regeneration] → `hive_adapters.dart` spec list + `build_runner` is a standard, already-documented step; CI/test run catches a missed adapter.
- [Outbox entity addition can break sync for everyone if forgotten] → `sync_module` registration is an explicit task with a test asserting every `MutationEntity` value has a replayer.

## Migration Plan

1. Backend first: `0012_parking_settings` migration (additive table) → deploy API. Old apps are unaffected (they never call the endpoint).
2. Flutter release: new feature, branding surfaces, `url_launcher`; against an old backend it shows defaults (Decision 10).
3. Rollback: drop the table with the inverse migration; Flutter rollback = revert the release (no data dependencies for other features).

## Open Questions

- Should the contact page live in bottom navigation or behind a home-screen action? (Trivial to switch; task implements it as a nav destination visible to both roles.)
- Whether to show the logo on the thermal receipt later (requires raster conversion) — parked as follow-up.
