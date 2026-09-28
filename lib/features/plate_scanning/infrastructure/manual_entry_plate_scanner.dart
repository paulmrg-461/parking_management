import 'package:cross_file/cross_file.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/plate_scan_result.dart';
import '../domain/repositories/plate_scanner.dart';

/// [PlateScanner] for platforms without on-device OCR (web): reports
/// itself unsupported so the UI goes straight to manual plate entry.
class ManualEntryPlateScanner implements PlateScanner {
  @override
  bool get isSupported => false;

  @override
  Future<PlateScanResult> scan(XFile image) async =>
      throw const ValidationFailure(
        'Plate scanning is not available here',
        ClientFailureCodes.scanUnavailable,
      );
}
