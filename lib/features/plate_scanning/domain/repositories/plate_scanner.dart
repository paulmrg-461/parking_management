import 'dart:io';

import '../entities/plate_scan_result.dart';

/// Port for scanning a vehicle plate from a captured image.
/// Implementations (e.g. ML Kit OCR) live in the infrastructure layer.
abstract class PlateScanner {
  Future<PlateScanResult> scan(File image);
}
