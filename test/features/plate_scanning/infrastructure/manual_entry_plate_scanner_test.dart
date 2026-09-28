import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/plate_scanning/infrastructure/manual_entry_plate_scanner.dart';

void main() {
  final scanner = ManualEntryPlateScanner();

  test('Success: reports that on-device scanning is not supported', () {
    expect(scanner.isSupported, isFalse);
  });

  test('Failure: scanning anyway fails with a ValidationFailure', () {
    expect(scanner.scan(XFile('scan.jpg')), throwsA(isA<ValidationFailure>()));
  });

  test('Security: never reads or echoes the image content', () async {
    final image = XFile.fromData(Uint8List.fromList('<script>'.codeUnits));

    await expectLater(
      scanner.scan(image),
      throwsA(predicate<Failure>((f) => !f.message.contains('<script>'))),
    );
  });
}
