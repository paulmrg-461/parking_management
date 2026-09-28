import 'package:cross_file/cross_file.dart';

import '../entities/plate_scan_result.dart';

/// Port for scanning a vehicle plate from a captured image.
/// Implementations (ML Kit OCR on mobile, manual entry on web) live in the
/// infrastructure layer.
abstract class PlateScanner {
  /// Whether this platform can recognise plates on-device. When `false` the
  /// UI hides every "scan" affordance and offers manual entry only.
  bool get isSupported;

  Future<PlateScanResult> scan(XFile image);
}
