## Context

`vehicles` completed the reference-data layer: vehicles are registered, looked up
by normalized plate, and managed by admins. The next operational need is to speed
up plate entry at check-in/check-out. This change delivers a client-side plate
scanning capability (camera + on-device OCR) with a manual fallback, so the
upcoming `check-in` change can pre-fill the plate field without the operator
typing it.

No backend work is required: scanning is on-device only and returns a normalized
candidate plate string that consumers pass to `VehicleRepository.findByPlate`.

## Goals / Non-Goals

**Goals:**
- Capture a still image with the `camera` plugin and feed it to on-device OCR.
- Extract a candidate plate via `google_mlkit_text_recognition`, normalized with
  the existing plate rule (uppercase, trimmed, no internal spaces).
- Provide a manual entry fallback so the operator is never blocked by camera or
  OCR failures.
- Emit a reviewable candidate plate (operator can edit before confirming).
- Keep the OCR implementation behind a `PlateScanner` port so it can be swapped
  without touching the cubit or presentation layer.

**Non-Goals:**
- Check-in/check-out flows (separate changes).
- Vehicle object detection / YOLO bounding-box localization (the `tflite_flutter`
  dependency and plate-detection model are deferred; this change ships OCR-only
  scanning first, as the proposal states manual fallback first).
- Backend endpoints or persistence (scanning is ephemeral, on-device).
- Continuous/streaming OCR scan; this is a one-shot still-image capture.

## Decisions

- **OCR adapter: `google_mlkit_text_recognition`** (Latin script). It is already
  named in the project stack and returns recognized text blocks; we post-process
  to the most plate-like block. `tflite_flutter` + a YOLO plate-detection model
  is a future enhancement for bounding-box localization, intentionally deferred
  to keep the first delivery small.
- **`PlateScanner` port** returns `PlateScanResult(rawText, candidatePlate,
  confidence)`. The adapter picks the most plate-like text block (alphanumeric,
  length 4-10, no vowels-only runs) and assigns a heuristic confidence; the cubit
  decides whether to prompt for review based on confidence.
- **Normalization is shared.** A pure `normalizePlate` function lives in the
  `plate_scanning` domain and mirrors the backend `normalize_plate` rule
  (uppercase, remove all whitespace, reject empty). This keeps the client rule
  consistent without coupling to the backend.
- **Manual fallback is always reachable.** The capture page exposes a "enter
  manually" action at all times; OCR failure auto-falls-back to manual entry
  with the OCR text pre-filled (if any) so the operator corrects rather than
  retypes.
- **Result is a candidate, not a confirmation.** The flow never looks up or
  creates a vehicle; it returns a normalized candidate string to the caller via
  navigation pop. Consumers (e.g. `check-in`) call `findByPlate` themselves.
- **Camera plugin: one-shot still capture** via `ImagePicker` (already a
  dependency) rather than a live `CameraController` preview, to keep the first
  delivery simple and avoid platform-specific camera lifecycle complexity. The
  `camera` dependency remains available for a future live-preview scanner.
- **DI: `PlateScanner` is a lazy singleton** (ML Kit model load is expensive);
  `PlateScanningCubit` is a factory (per-page instance), matching the existing
  cubit registration pattern.

## Risks / Trade-offs

- [OCR accuracy on dirty/angled plates] → the candidate-review step and manual
  fallback absorb errors; no silent auto-confirm.
- [ML Kit text recognition may return multiple blocks] → the adapter heuristically
  selects the most plate-like block; confidence is heuristic (not a true
  probability). Acceptable for v1.
- [Plate formats vary by country] → only non-empty normalization is enforced, no
  strict format validation, matching the `vehicles` decision.
- [`google_mlkit_text_recognition` native availability on web] → ML Kit is not
  available on web. On web, the scanner auto-falls-back to manual entry. This is
  acceptable given android is the primary operational target.
- [`tflite_flutter` not added in this change] → the proposal mentions it as a
  scoped future dependency; deferred to the plate-detection enhancement to avoid
  an unused heavy dependency.

## Migration Plan

1. Additive only: a new `features/plate_scanning` feature slice and a `/scan`
   route. No migrations, no backend changes, no schema changes.
2. Add `google_mlkit_text_recognition` to `pubspec.yaml` dependencies; run
   `flutter pub get`.
3. Register `PlateScanner` and `PlateScanningCubit` in the DI container.

## Open Questions

- None blocking. The live-preview `CameraController` and `tflite_flutter`
  plate-detection model are explicitly deferred to a future enhancement.
