import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';

void main() {
  test(
    'Success: VersionConflictFailure carries the server row and its code',
    () {
      final failure = VersionConflictFailure({
        'id': 5,
        'version': 8,
        'color': 'red',
      });

      expect(failure.code, 'VersionConflictError');
      expect(failure.serverRow?['version'], 8);
      expect(failure.message, contains('changed'));
    },
  );

  test('Security: it is not a ValidationFailure', () {
    // `SyncService` must match it before the ValidationFailure case, otherwise
    // a mergeable conflict would be dead-lettered.
    expect(const VersionConflictFailure(null), isNot(isA<ValidationFailure>()));
    expect(const VersionConflictFailure(null), isA<Failure>());
  });

  test('Success: a deletion conflict carries a null row', () {
    expect(const VersionConflictFailure(null).serverRow, isNull);
  });
}
