import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/plate_scanning/domain/normalize_plate.dart';

void main() {
  test('Success: normalizes a plate to uppercase with no whitespace', () {
    expect(normalizePlate('  abc 123 '), 'ABC123');
  });

  test('Failure: rejects an empty plate with ValidationFailure', () {
    expect(
      () => normalizePlate('   '),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('Security: strips whitespace so injected plate cannot bypass checks', () {
    expect(normalizePlate('\t A B C 1 2 3 \n'), 'ABC123');
  });
}
