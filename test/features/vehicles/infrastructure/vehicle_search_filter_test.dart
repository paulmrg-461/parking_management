import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/vehicles/infrastructure/vehicle_remote_data_source.dart';

void main() {
  test('Success: the registry filter searches plate, owner and phone', () {
    expect(
      vehicleSearchFilter('abc 12'),
      'plate.ilike."%abc 12%",owner_name.ilike."%abc 12%",'
      'owner_phone.ilike."%abc 12%"',
    );
  });

  test('Failure: a blank term has no filter', () {
    expect(vehicleSearchFilter(''), isNull);
    expect(vehicleSearchFilter('   '), isNull);
  });

  test('Security: quotes in the term cannot break the or-expression', () {
    final filter = vehicleSearchFilter('a"b,c');

    expect(filter, contains('plate.ilike."%ab,c%"'));
    expect(filter, isNot(contains('""')));
  });
}
