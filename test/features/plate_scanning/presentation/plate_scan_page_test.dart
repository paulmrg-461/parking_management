import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cross_file/cross_file.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/plate_scanning/application/plate_scanning_cubit.dart';
import 'package:parking_management/features/plate_scanning/domain/entities/plate_scan_result.dart';
import 'package:parking_management/features/plate_scanning/domain/repositories/plate_scanner.dart';
import 'package:parking_management/features/plate_scanning/domain/repositories/plate_image_capture.dart';
import 'package:parking_management/features/plate_scanning/infrastructure/manual_entry_plate_scanner.dart';
import 'package:parking_management/features/plate_scanning/presentation/plate_scan_page.dart';

class _FakeScanner implements PlateScanner {
  _FakeScanner.result(this._result) : _error = null;
  _FakeScanner.failing(Failure error) : _error = error, _result = null;

  final PlateScanResult? _result;
  final Failure? _error;

  @override
  bool get isSupported => true;

  @override
  Future<PlateScanResult> scan(XFile image) async {
    if (_error != null) {
      throw _error;
    }
    return _result!;
  }
}

class _FakeCapture implements PlateImageCapture {
  _FakeCapture(this._file);

  final XFile? _file;

  @override
  Future<XFile?> capture() async => _file;
}

Widget _scanPage({
  required PlateScanner scanner,
  required PlateImageCapture capture,
}) {
  return MaterialApp(
    home: BlocProvider<PlateScanningCubit>(
      create: (_) => PlateScanningCubit(scanner),
      child: PlateScanPage(capture: capture),
    ),
  );
}

void main() {
  testWidgets('Success: captures, reviews, and confirms a scanned plate', (
    tester,
  ) async {
    String? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => BlocProvider<PlateScanningCubit>(
                    create: (_) => PlateScanningCubit(
                      _FakeScanner.result(
                        const PlateScanResult(
                          rawText: 'ABC123',
                          candidatePlate: 'ABC123',
                          confidence: 0.9,
                        ),
                      ),
                    ),
                    child: PlateScanPage(
                      capture: _FakeCapture(XFile('scan.jpg')),
                    ),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Capture plate'));
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(popped, 'ABC123');
  });

  testWidgets('Failure: shows an error message when the scanner throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scanPage(
        scanner: _FakeScanner.failing(
          const ValidationFailure('Could not read text from image'),
        ),
        capture: _FakeCapture(XFile('scan.jpg')),
      ),
    );

    await tester.tap(find.text('Capture plate'));
    await tester.pumpAndSettle();

    expect(find.text('Could not read text from image'), findsOneWidget);
  });

  testWidgets(
    'Security: camera cancellation/denial falls back to manual entry without crashing',
    (tester) async {
      await tester.pumpWidget(
        _scanPage(
          scanner: _FakeScanner.result(
            const PlateScanResult(
              rawText: '',
              candidatePlate: '',
              confidence: 0.0,
            ),
          ),
          capture: _FakeCapture(null),
        ),
      );

      await tester.tap(find.text('Capture plate'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Enter the plate manually'), findsOneWidget);
    },
  );

  testWidgets('Failure: without scanner support only manual entry is offered', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<PlateScanningCubit>(
          create: (_) => PlateScanningCubit(ManualEntryPlateScanner()),
          child: PlateScanPage(capture: _FakeCapture(null)),
        ),
      ),
    );

    expect(find.text('Capture plate'), findsNothing);
    expect(find.widgetWithText(TextField, 'Plate'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });
}
