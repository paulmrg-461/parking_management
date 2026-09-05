## 1. Flutter domain

- [x] 1.1 Add `PlateScanResult` entity (`rawText`, `candidatePlate`, `confidence`)
- [x] 1.2 Add `PlateScanner` abstract port (`Future<PlateScanResult> scan(File image)`)
- [x] 1.3 Add pure `normalizePlate` function (uppercase, trim, remove internal spaces, reject empty)
- [x] 1.4 Write 3 tests (Success / Failure / Security) for `normalizePlate`

## 2. Flutter infrastructure

- [ ] 2.1 Add `google_mlkit_text_recognition` to `pubspec.yaml` and run `flutter pub get`
- [ ] 2.2 Add `MlKitPlateScanner` adapter implementing `PlateScanner` (pick most plate-like text block, heuristic confidence)
- [ ] 2.3 Add `ImagePickerPlateCapture` helper that returns an `XFile` via `image_picker`
- [ ] 2.4 Write 3 tests (Success / Failure / Security) for the scanner adapter (use a fake `TextRecognizer`)

## 3. Flutter application

- [ ] 3.1 Add `PlateScanningCubit` with Equatable states (`initial`, `capturing`, `scanning`, `success`, `failure`, `manualEntry`)
- [ ] 3.2 Orchestrate: capture -> scan -> normalize -> emit candidate or fall back to manual entry
- [ ] 3.3 Register `PlateScanner` (lazy singleton) and `PlateScanningCubit` (factory) in the DI container
- [ ] 3.4 Write 3 tests (Success / Failure / Security) for the cubit (use a fake `PlateScanner`)

## 4. Flutter presentation

- [ ] 4.1 Add `PlateScanPage` with capture button, candidate review field, and manual-entry fallback
- [ ] 4.2 Add the `/scan` route (authenticated) to `app_router.dart`
- [ ] 4.3 Return the confirmed candidate plate via navigation pop
- [ ] 4.4 Write 3 tests (Success / Failure / Security) for the scan page

## 5. Verification

- [ ] 5.1 Confirm `flutter analyze` passes with 0 issues
- [ ] 5.2 Confirm `flutter test` passes
- [ ] 5.3 Confirm `openspec validate plate-scanning` passes
