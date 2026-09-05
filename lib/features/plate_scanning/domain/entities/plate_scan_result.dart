import 'package:equatable/equatable.dart';

/// Result of a plate scan: the raw OCR text, a normalized candidate plate,
/// and a heuristic confidence (0.0 to 1.0) used to decide whether to
/// prompt the operator for review.
class PlateScanResult extends Equatable {
  const PlateScanResult({
    required this.rawText,
    required this.candidatePlate,
    required this.confidence,
  });

  final String rawText;
  final String candidatePlate;
  final double confidence;

  @override
  List<Object?> get props => [rawText, candidatePlate, confidence];
}
