## Why

The parking lot identity is hardcoded across the app: the thermal and PDF receipts print a fixed `'PARQUEADERO'` header (`esc_pos_generator.dart:19`, `system_dialog_receipt_printer.dart:36`), the app title comes from a static ARB string, and the login screen shows a generic icon. There is no way for an operator to register their own name, logo, address, opening hours, phone, website or WhatsApp — the product cannot be branded per parking lot.

## What Changes

- New **parking settings** record (singleton): display name, logo, address, opening schedule, phone, website, WhatsApp number, plus optional contact blurb.
- Backend: new `parking_settings` table (Alembic migration), `GET/PATCH /api/settings` (admin write, any authenticated read) and `POST /api/settings/logo` upload + `GET /api/settings/logo/{version}` serving the image bytes (multipart, same local storage used by evidence photos).
- Flutter: new `settings` feature (hexagonal) with a `ParkingSettings` entity, repository port, REST + Hive adapters, outbox-synced writes (`MutationEntity.settings` + replayer), and an admin settings form page (logo picker via `image_picker`).
- Branding consumption: receipts (thermal ESC/POS + PDF) header/footer use the configured data; app title and login header show the name/logo; a floating WhatsApp action (`wa.me` link) and a contact/about admin page expose address, schedule, phone, website.
- Offline: settings are cached in Hive; edits queue through the existing outbox and replay when connectivity returns.

## Capabilities

### New Capabilities

- `parking-settings`: configuring the parking lot's identity (name, logo, address, schedule, phone, website, WhatsApp) and how that data is served, synced, displayed, and printed across receipts, app chrome, WhatsApp action and contact page.

### Modified Capabilities

<!-- none: receipts, app title and offline sync entity lists are not spec'd as requirements today -->

## Impact

- **Backend**: `backend/app/infrastructure/models.py` (+`ParkingSettingsModel`), new `backend/app/presentation/routes/settings.py` + schemas, service, repository port/impl, `deps.py` wiring, `main.py::_ROUTERS`, new migration `backend/alembic/versions/0012_parking_settings.py`, logo storage reusing `EvidenceStorage`-style local files under a `settings` root, new `backend/tests/test_settings_endpoints.py`.
- **Flutter**: new `lib/features/settings/` feature, DI module + `injection.dart` line, deferred admin route in `app_router.dart` + nav destination, `MutationEntity.settings` in `core/sync/pending_mutation.dart`, replayer registration in `sync_module.dart`, `hive_adapters.dart` regen (new entity), ETag cache path in `core_module.dart`, `appTitle`/login/home widgets, `ReceiptData` gains parking identity fields consumed by `esc_pos_generator.dart` and `system_dialog_receipt_printer.dart`, floating WhatsApp button in the shell.
- **i18n**: new `app_es.arb` / `app_en.arb` strings (Spanish template).
- **Dependencies**: one new package — `url_launcher` (WhatsApp `wa.me`, `tel:` and website links); `image_picker` for the logo is already present.
- **Breaking**: none (defaults keep current behavior when settings are unset).
