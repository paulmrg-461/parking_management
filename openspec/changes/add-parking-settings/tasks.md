## 1. Backend: settings record

- [ ] 1.1 Write `backend/tests/test_settings_endpoints.py` first: Success (GET defaults; admin PATCH merges and persists), Failure (422 empty name / bad website, 401 unauthenticated PATCH), Security (operator PATCH → 403, record unchanged)
- [ ] 1.2 Add Alembic migration `backend/alembic/versions/0012_parking_settings.py` (singleton table: name, address, schedule, phone, website, whatsapp, logo_version, updated_at) + `ParkingSettingsModel` in `infrastructure/models.py`
- [ ] 1.3 Add domain port dataclass + pydantic schemas (`GET` read model, `PATCH` write model with field validators) + SQLAlchemy repository (`get`/`patch` upsert on id 1)
- [ ] 1.4 Add `ParkingSettingsService` (`backend/app/application/settings_service.py`) with defaults (name `Parqueadero`, logo_version 0)
- [ ] 1.5 Add `backend/app/presentation/routes/settings.py` (`GET` public, `PATCH` admin-only), register service/repo in `deps.py`, add route to `_ROUTERS` in `main.py:32`
- [ ] 1.6 Run backend test suite (`pytest`) — all settings tests green

## 2. Backend: logo upload and serving

- [ ] 2.1 Extend `test_settings_endpoints.py` first: Success (admin PNG upload bumps `logo_version`, `GET /api/settings/logo` returns bytes + content type), Failure (text file → 422, >5 MB → 413), Security (operator upload → 403, version unchanged)
- [ ] 2.2 Add `settings_storage_path` to `core/config.py`, a local settings-logo storage (mirror `local_evidence_storage.py`), `POST /api/settings/logo` (multipart, reuse `uploads.py` validation) and public `GET /api/settings/logo`
- [ ] 2.3 Re-run `pytest` — logo tests green

## 3. Flutter: settings feature (domain + data)

- [ ] 3.1 Write repository/cubit tests first (`test/features/settings/…`): Success (load caches remote; save online updates cache), Failure (offline load falls back to cache/defaults; offline save enqueues mutation; logo upload offline → error, cache untouched), Security (operator hitting settings route is redirected — router test)
- [ ] 3.2 Create `lib/features/settings/` skeleton: `ParkingSettings` entity (Equatable), `ParkingSettingsRepository` port, DTO + `toDomain()` + `json_serializable` codegen
- [ ] 3.3 Implement `HiveParkingSettingsLocalDataSource` (box `parking_settings`, logo bytes box `logo_cache` keyed by version) and `DioParkingSettingsRemoteDataSource` (`/api/settings`, `/api/settings/logo`)
- [ ] 3.4 Implement `ParkingSettingsRepositoryImpl` (load: remote→cache, network→cache→defaults; save: optimistic local + outbox enqueue on `NetworkFailure`)
- [ ] 3.5 Add `MutationEntity.settings` in `core/sync/pending_mutation.dart:7`, implement `ParkingSettingsMutationReplayer`, register in `sync_module.dart:24-46` + add a test asserting every enum value has a replayer
- [ ] 3.6 Add `ParkingSettings` to `hive_adapters.dart` spec list and run `build_runner`; add `/api/settings` to the ETag cache paths in `core_module.dart:22`

## 4. Flutter: DI and root branding

- [ ] 4.1 Create `lib/app/di/modules/settings_module.dart` (local, remote, repository as lazy singletons; `SettingsCubit` factory) and register it in `injection.dart:37`
- [ ] 4.2 Implement root `BrandingCubit` (seed from Hive, refresh from backend, expose `ParkingSettings` + defaults) and provide it above `MaterialApp` in `lib/app/app.dart`

## 5. Flutter: admin settings form

- [ ] 5.1 Add `url_launcher` to `pubspec.yaml` and run `flutter pub get`
- [ ] 5.2 Create deferred route entry `lib/app/router/deferred/settings_entry.dart`, register `/settings` in `app_router.dart` (admin-only by default), add management nav destination in `app_destinations.dart`
- [ ] 5.3 Build `lib/features/settings/presentation/settings_page.dart`: form for name/address/schedule/phone/website/WhatsApp with validation and l10n labels, save via cubit, success/failure feedback
- [ ] 5.4 Add logo section: `image_picker` pick → upload through repository → preview (cached bytes) + upload-failure message when offline

## 6. Flutter: contact page and link actions

- [ ] 6.1 Add `/contact` to `operatorRoutes` in `route_access.dart:10`, deferred entry + nav destination
- [ ] 6.2 Build read-only contact page (logo, name, address, schedule, phone, website, WhatsApp) with `url_launcher` actions (`tel:`, `https://`, `wa.me/<digits>`); shared helper normalizes WhatsApp digits
- [ ] 6.3 Test the WhatsApp URL builder: Success (`+57 300 111 2233` → `https://wa.me/573001112233`), Failure (empty → null), Security (no `+/spaces` leak into the URL)

## 7. Flutter: WhatsApp floating action

- [ ] 7.1 Add the floating WhatsApp action to `app_shell.dart` driven by `BrandingCubit` (hidden when unconfigured, visible to both roles, opens `wa.me` link)

## 8. Flutter: receipts show parking identity

- [ ] 8.1 Extend receipt tests first: Success (thermal output contains configured name + contact footer, no `PARQUEADERO` literal), Failure (no cached settings → `PARQUEADERO` fallback, print still succeeds), Security (pending-sync receipts still omit amount/ticket)
- [ ] 8.2 Change `EscPosGenerator.build(data, settings)` to emit configured header/footer; inject `ParkingSettingsRepository` into `BluetoothPrintScanner` and load cache-first before building bytes
- [ ] 8.3 Inject `ParkingSettingsRepository` into `SystemDialogReceiptPrinter`; PDF header uses name + logo image when present, contact footer when configured
- [ ] 8.4 Run `flutter test test/features/receipt_printing` — green

## 9. Flutter: app chrome + l10n

- [ ] 9.1 Add ARB keys (settings page, contact page, WhatsApp action, validation messages) to `app_es.arb` (template) and `app_en.arb`, regenerate localizations
- [ ] 9.2 Home AppBar, login header/logo and `onGenerateTitle` read `BrandingCubit` with the localized default as fallback

## 10. Verification

- [ ] 10.1 `flutter analyze` clean and full `flutter test` green
- [ ] 10.2 Backend `pytest` green and `alembic upgrade head` applies cleanly on a fresh DB
- [ ] 10.3 `flutter build apk --debug` and `flutter build web --release` succeed
- [ ] 10.4 Manual smoke: configure data → check contact page, WhatsApp link, login brand, thermal + PDF receipts; airplane mode → load and edit settings, then re-enable network and confirm outbox replay
