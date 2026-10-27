import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/vehicles/application/vehicles_cubit.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
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

  VehiclesCubit fastCubit() => VehiclesCubit(
    vehicles,
    categories,
    searchDebounce: Duration.zero,
  );

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

  test('Success: create persists and reports the new vehicle', () async {
    await cubit.load();

    await cubit.create(
      const CreateVehicleCommand(plate: 'XYZ789', categoryId: 1),
    );

    expect(loaded().vehicles.map((v) => v.plate), ['ABC123', 'XYZ789']);
    final submission = loaded().submission;
    expect(submission, isA<SubmissionSucceeded<Object?>>());
    expect((submission as SubmissionSucceeded).result, isA<Vehicle>());
  });

  test('Success: updating keeps the submission idle (no snack)', () async {
    await cubit.load();

    await cubit.update(const UpdateVehicleCommand(id: 1, brand: 'Mazda'));

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

  test('Success: searching filters server-side and keeps the term', () async {
    final searchCubit = fastCubit();
    addTearDown(searchCubit.close);
    vehicles.vehicles = const [
      Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
      Vehicle(id: 2, plate: 'XYZ999', categoryId: 1),
    ];
    await searchCubit.load();

    searchCubit.search('xyz');
    await Future<void>.delayed(Duration.zero);

    final state = searchCubit.state as VehiclesLoaded;
    expect(state.query, 'xyz');
    expect(state.vehicles.map((v) => v.plate), ['XYZ999']);
  });

  test('Success: a query with no matches loads an empty page', () async {
    final searchCubit = fastCubit();
    addTearDown(searchCubit.close);
    await searchCubit.load();

    searchCubit.search('zzz');
    await Future<void>.delayed(Duration.zero);

    final state = searchCubit.state as VehiclesLoaded;
    expect(state.vehicles, isEmpty);
    expect(state.query, 'zzz');
  });

  test('Success: refreshing keeps the active search term', () async {
    final searchCubit = fastCubit();
    addTearDown(searchCubit.close);
    vehicles.vehicles = const [
      Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
      Vehicle(id: 2, plate: 'XYZ999', categoryId: 1),
    ];
    await searchCubit.load();
    searchCubit.search('abc');
    await Future<void>.delayed(Duration.zero);

    await searchCubit.load();

    expect((searchCubit.state as VehiclesLoaded).query, 'abc');
    expect((searchCubit.state as VehiclesLoaded).vehicles.map((v) => v.plate), [
      'ABC123',
    ]);
  });
}
