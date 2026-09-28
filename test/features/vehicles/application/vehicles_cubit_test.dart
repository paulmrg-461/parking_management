import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/vehicles/application/vehicles_cubit.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/fake_category_repository.dart';
import '../../../helpers/fake_vehicle_repository.dart';

const _abc = Vehicle(id: 1, plate: 'ABC123', categoryId: 1);

void main() {
  late FakeVehicleRepository vehicles;
  late FakeCategoryRepository categories;
  late VehiclesCubit cubit;

  setUp(() {
    vehicles = FakeVehicleRepository(const [_abc]);
    categories = FakeCategoryRepository(const [Category(id: 1, name: 'Car')]);
    cubit = VehiclesCubit(vehicles, categories);
  });

  tearDown(() => cubit.close());

  VehiclesLoaded loaded() => cubit.state as VehiclesLoaded;

  test(
    'Success: load emits vehicles with precomputed category names',
    () async {
      await cubit.load();

      expect(loaded().vehicles, const [_abc]);
      expect(loaded().categoryNames, {1: 'Car'});
      expect(loaded().categoryNameOf(_abc), 'Car');
    },
  );

  test('Failure: load failure emits failure state', () async {
    vehicles.listError = const NetworkFailure('offline');

    await cubit.load();

    expect(cubit.state, const VehiclesFailure('offline'));
  });

  test('Success: create persists and reloads with Idle submission', () async {
    await cubit.load();

    await cubit.create(
      const CreateVehicleCommand(plate: 'XYZ789', categoryId: 1),
    );

    expect(loaded().vehicles.map((v) => v.plate), ['ABC123', 'XYZ789']);
    expect(loaded().submission, const SubmissionIdle());
  });

  test(
    'Failure: a failed delete keeps the list and reports SubmissionFailed',
    () async {
      await cubit.load();
      vehicles.writeError = const ValidationFailure(
        'Vehicle has open sessions',
      );

      await cubit.delete(1);

      expect(loaded().vehicles, const [_abc]);
      expect(
        loaded().submission,
        const SubmissionFailed('Vehicle has open sessions'),
      );
    },
  );

  test(
    'Success: loadMore appends the next page when X-Total-Count allows',
    () async {
      vehicles
        ..vehicles = [
          for (var i = 1; i <= 70; i++)
            Vehicle(id: i, plate: 'P$i', categoryId: 1),
        ]
        ..total = 70;

      await cubit.load();
      expect(loaded().hasMore, isTrue);
      await cubit.loadMore();

      expect(loaded().vehicles, hasLength(70));
      expect(loaded().hasMore, isFalse);
      expect(vehicles.pageRequests, [(0, 50), (50, 50)]);
    },
  );

  test(
    'Security: unknown categories fall back to the id, never crash',
    () async {
      categories.listError = const NetworkFailure('offline');

      await cubit.load();

      expect(loaded().categoryNameOf(_abc), 'Category 1');
      await cubit.loadMore();
      expect(vehicles.pageRequests, [(0, 50)]);
    },
  );
}
