import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';

void main() {
  test('Success: out-of-service spots shrink the usable pool', () {
    const capacity = CapacitySnapshot(
      carOpen: 3,
      carCapacity: 8,
      carOutOfService: 2,
      carReserved: 1,
    );

    expect(capacity.carAvailable, 6);
    expect(capacity.carFree, 2);
    expect(capacity.carsFull, isFalse);
  });

  test('Failure: a group with everything out of service is full', () {
    const capacity = CapacitySnapshot(carCapacity: 4, carOutOfService: 4);

    expect(capacity.carAvailable, 0);
    expect(capacity.carFree, 0);
    expect(capacity.carsFull, isTrue);
  });

  test('Security: no configured limit ignores the out-of-service counter', () {
    const capacity = CapacitySnapshot(carOpen: 9, carOutOfService: 3);

    expect(capacity.carAvailable, 0);
    expect(capacity.carFree, 0);
    expect(capacity.carsFull, isFalse);
  });
}
