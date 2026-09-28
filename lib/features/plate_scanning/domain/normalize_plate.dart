// Normalizes a plate string: uppercase, trimmed, with all internal
// whitespace removed. Rejects empty plates with a [ValidationFailure].
//
// Mirrors the backend `normalize_plate` rule so the client and server
// agree on plate format without coupling.
import '../../../core/error/failure.dart';

String normalizePlate(String input) {
  final normalized = input.replaceAll(RegExp(r'\s'), '').toUpperCase();
  if (normalized.isEmpty) {
    throw const ValidationFailure(
      'Plate must not be empty',
      ClientFailureCodes.emptyPlate,
    );
  }
  return normalized;
}
