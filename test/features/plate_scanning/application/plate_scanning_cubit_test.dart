import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/plate_scanning/application/plate_scanning_cubit.dart';
import 'package:parking_management/features/plate_scanning/domain/entities/plate_scan_result.dart';
import 'package:parking_management/features/plate_scanning/domain/repositories/plate_scanner.dart';

class _FakePlateScanner implements PlateScanner {
  _FakePlateScanner.returning(this._result) : _error = null;
  _FakePlateScanner.failing(Failure error)
      : _error = error,
        _result = null;

  final PlateScanResult? _result;
  final Failure? _error;

  @override
  Future<PlateScanResult> scan(File image) async {
    if (_error != null) {
      throw _error;
    }
    return _result!;
  }
}

void main() {
  final image = File('scan.jpg');

  test('Success: scan emits a normalized candidate from the OCR result', () async {
    final cubit = PlateScanningCubit(
      _FakePlateScanner.returning(
        const PlateScanResult(rawText: 'ABC123', candidatePlate: 'ABC123', confidence: 0.9),
      ),
    );

    await cubit.scan(image);

    expect(cubit.state, const PlateScanningSuccess('ABC123', 0.9));
  });

  test('Failure: scan emits a failure state when the scanner throws', () async {
    final cubit = PlateScanningCubit(
      _FakePlateScanner.failing(const ValidationFailure('Could not read text from image')),
    );

    await cubit.scan(image);

    expect(
      cubit.state,
      const PlateScanningFailure('Could not read text from image'),
    );
  });

  test('Security: normalizes a garbage/spaced OCR candidate before emitting success', () async {
    final cubit = PlateScanningCubit(
      _FakePlateScanner.returning(
        const PlateScanResult(rawText: '  abc 123 ', candidatePlate: '  abc 123 ', confidence: 0.5),
      ),
    );

    await cubit.scan(image);

    expect(cubit.state, const PlateScanningSuccess('ABC123', 0.5));
  });

  test('falls back to manual entry when OCR finds no plate-like text', () async {
    final cubit = PlateScanningCubit(
      _FakePlateScanner.returning(
        const PlateScanResult(rawText: 'PARKING', candidatePlate: '', confidence: 0.0),
      ),
    );

    await cubit.scan(image);

    expect(cubit.state, const PlateScanningManualEntry(prefill: 'PARKING'));
  });

  test('confirmManual normalizes and validates manual input', () {
    final cubit = PlateScanningCubit(_FakePlateScanner.returning(
      const PlateScanResult(rawText: '', candidatePlate: '', confidence: 0.0),
    ));

    cubit.confirmManual('  xyz 789 ');

    expect(cubit.state, const PlateScanningSuccess('XYZ789', 1.0));
  });
}
