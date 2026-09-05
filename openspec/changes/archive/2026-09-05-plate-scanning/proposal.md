## Why

Check-in and check-out resolve vehicles by plate. Typing plates manually is slow
and error-prone for operators. Automatic plate scanning accelerates entry/exit and
reduces transcription mistakes. This change delivers a scanning capability that the
upcoming `check-in` change will consume to pre-fill the plate field, with a manual
fallback so the operator is never blocked when the camera or OCR fails.

## What Changes

- Add a Flutter `plate_scanning` feature (hexagonal) with a `PlateScanner` domain
  port, a `google_mlkit_text_recognition` adapter, and a manual-entry fallback.
- Add a camera capture flow (`camera` plugin, still-image one-shot) that feeds the
  OCR adapter and returns a candidate plate string.
- Add plate normalization + validation that reuses the existing
  `normalize_plate` rule (uppercase, trimmed, no internal spaces).
- Expose a `PlateScanningCubit` that orchestrates: capture -> OCR -> normalize ->
  confidence/candidate selection -> emit result or fallback to manual entry.
- No backend changes: scanning is a client-side capability. The result is a
  normalized plate string that consumers (e.g. `check-in`) pass to
  `VehicleRepository.findByPlate`.

## Capabilities

### New Capabilities

- `plate-scanning`: capture a vehicle plate via camera OCR or manual entry and
  return a normalized candidate plate, with a manual fallback when OCR is
  unavailable or low-confidence.

### Modified Capabilities

(none)

## Impact

- Flutter: new `features/plate_scanning` feature; `PlateScanner` port + ML Kit
  adapter; `PlateScanningCubit`; camera capture page; DI registration; route
  `/scan` (authenticated). Reuses `camera` (already a dependency) and adds
  `google_mlkit_text_recognition` + `tflite_flutter` as scoped dependencies.
- Backend: none (scanning is on-device only).
- `openspec/specs/` gains `plate-scanning` after archive.
