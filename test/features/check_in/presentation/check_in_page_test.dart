import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/spots/domain/entities/parking_spot.dart';
import 'package:parking_management/features/check_out/domain/entities/occupancy_snapshot.dart';
import 'package:parking_management/features/categories/domain/repositories/category_repository.dart';
import 'package:parking_management/features/check_in/application/check_in_cubit.dart';
import 'package:parking_management/features/check_in/application/create_check_in.dart';
import 'package:parking_management/features/check_in/application/vehicle_lookup_cubit.dart';
import 'package:parking_management/features/check_in/domain/entities/new_vehicle_info.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:parking_management/features/check_in/presentation/check_in_page.dart';
import 'package:parking_management/app/di/injection.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/storage/key_value_store.dart';
import 'package:parking_management/core/widgets/qr_code.dart';
import 'package:parking_management/features/home/application/dashboard_cubit.dart';
import 'package:parking_management/features/reservations/domain/repositories/reservation_repository.dart';
import 'package:parking_management/features/plate_scanning/application/plate_scanning_cubit.dart';
import 'package:parking_management/features/plate_scanning/domain/entities/plate_scan_result.dart';
import 'package:parking_management/features/plate_scanning/domain/repositories/plate_image_capture.dart';
import 'package:parking_management/features/plate_scanning/domain/repositories/plate_scanner.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/domain/repositories/vehicle_repository.dart';

import '../../../helpers/fake_check_out_repository.dart';
import '../../../helpers/fake_reservation_repository.dart';
import '../../../helpers/fake_key_value_store.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_png.dart';

class _FakeCheckInRepository implements CheckInRepository {
  int createCalls = 0;
  Failure? createError;
  String? lastPlate;
  bool? lastLeftKeys;
  int? lastSpotId;
  NewVehicleInfo? lastNewVehicle;
  List<XFile> lastPhotos = const [];

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
    bool leftKeys = false,
    int? spotId,
  }) async {
    createCalls++;
    lastPlate = plate;
    lastLeftKeys = leftKeys;
    lastSpotId = spotId;
    lastNewVehicle = newVehicle;
    lastPhotos = photos;
    final error = createError;
    if (error != null) throw error;
    return ParkingSession(
      id: 2,
      plate: plate,
      status: ParkingSessionStatus.open,
      entryTime: DateTime(2026, 1, 1),
      photoCount: 0,
    );
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async => [
    ParkingSession(
      id: 1,
      plate: 'OPEN01',
      status: ParkingSessionStatus.open,
      entryTime: DateTime(2026, 1, 1),
      photoCount: 2,
    ),
  ];
}

class _FakeVehicleRepository implements VehicleRepository {
  _FakeVehicleRepository({this.plates = const []});

  final List<String> plates;

  static const known = Vehicle(
    id: 7,
    plate: 'ABC123',
    categoryId: 1,
    color: 'Red',
    brand: 'Mazda',
  );

  @override
  Future<PagedResult<Vehicle>> listPage({
    int offset = 0,
    int limit = defaultPageSize,
    String? plate,
  }) async {
    final items = [
      for (final (index, value) in plates.indexed)
        Vehicle(id: index + 1, plate: value, categoryId: 1),
    ];
    return PagedResult(items, total: items.length);
  }

  @override
  Future<Vehicle?> findByPlate(String plate) async =>
      plate == known.plate ? known : null;

  @override
  Future<List<Vehicle>> list() => throw UnimplementedError();

  @override
  Future<Vehicle> create(CreateVehicleCommand command) =>
      throw UnimplementedError();

  @override
  Future<Vehicle> update(UpdateVehicleCommand command) =>
      throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();
}

class _FakeCategoryRepository implements CategoryRepository {
  @override
  Future<List<Category>> list() async => const [
    Category(id: 1, name: 'Car'),
    Category(id: 2, name: 'Motorcycle'),
  ];

  @override
  Future<Category> create(String name) => throw UnimplementedError();

  @override
  Future<Category> update(int id, String name) => throw UnimplementedError();

  @override
  Future<Category> setCapacity(int id, int capacity) =>
      throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();
}

class _FakeCapture implements PlateImageCapture {
  _FakeCapture({this.returnsPhoto = false});

  final bool returnsPhoto;

  @override
  Future<XFile?> capture() async => returnsPhoto
      ? XFile.fromData(testPng, path: 'evidence.png', name: 'evidence.png')
      : null;
}

class _FakeScanner implements PlateScanner {
  _FakeScanner({this.plate, this.error});

  final String? plate;
  final Failure? error;

  @override
  bool get isSupported => true;

  @override
  Future<PlateScanResult> scan(XFile image) async {
    if (error != null) {
      throw error!;
    }
    return PlateScanResult(
      rawText: plate ?? '',
      candidatePlate: plate ?? '',
      confidence: 0.9,
    );
  }
}

void main() {
  late _FakeCheckInRepository checkIns;
  late FakeCheckOutRepository occupancy;
  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  bool hapticFired() =>
      platformCalls.any((call) => call.method == 'HapticFeedback.vibrate');

  Future<void> pumpPage(
    WidgetTester tester, {
    bool canScan = true,
    bool photos = false,
    _FakeScanner? scanner,
    List<CategoryOccupancySnapshot> occupancyCategories = const [],
    CapacitySnapshot space = CapacitySnapshot.empty,
    SlotBoard? board,
    String? initialPlate,
    void Function(BuildContext context, String plate)? onMarkExit,
    ReservationRepository? reservations,
    List<String> knownPlates = const [],
    bool withVehicles = true,
  }) async {
    // Tall viewport: the form, the keys switch and the sessions accordion must
    // fit without fighting the CustomScrollView while tapping.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    checkIns = _FakeCheckInRepository();
    occupancy = FakeCheckOutRepository(categories: occupancyCategories)
      ..capacityToReturn = space
      ..slotBoardToReturn = board ?? SlotBoard.empty;
    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider<CheckInCubit>(
              create: (_) => CheckInCubit(CreateCheckIn(checkIns), checkIns),
            ),
            BlocProvider<DashboardCubit>(
              create: (_) => DashboardCubit(occupancy),
            ),
            BlocProvider<VehicleLookupCubit>(
              create: (_) => VehicleLookupCubit(
                _FakeVehicleRepository(),
                _FakeCategoryRepository(),
              ),
            ),
            BlocProvider<PlateScanningCubit>(
              create: (_) =>
                  PlateScanningCubit(scanner ?? _FakeScanner(plate: 'ABC123')),
            ),
          ],
          child: CheckInPage(
            capture: _FakeCapture(returnsPhoto: photos),
            canScan: canScan,
            initialPlate: initialPlate,
            onMarkExit: onMarkExit,
            reservations: reservations,
            vehicles: withVehicles
                ? _FakeVehicleRepository(plates: knownPlates)
                : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder plateField() => find.widgetWithText(TextField, 'Placa');

  Future<void> enterPlate(WidgetTester tester, String plate) async {
    await tester.enterText(plateField(), plate);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Finder submitButton() =>
      find.widgetWithText(FilledButton, 'Registrar entrada');

  /// The form scrolls; make the submit button visible before tapping it.
  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(submitButton());
    await tester.pumpAndSettle();
    await tester.tap(submitButton());
    await tester.pumpAndSettle();
  }

  bool submitEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(submitButton()).onPressed != null;

  Finder categoryField() =>
      find.widgetWithText(DropdownButtonFormField<int>, 'Categoría');

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('Success: a full category is disabled in the dropdown', (
    tester,
  ) async {
    await pumpPage(
      tester,
      occupancyCategories: const [
        CategoryOccupancySnapshot(
          categoryId: 1,
          name: 'Car',
          count: 1,
          capacity: 1,
          isFull: true,
        ),
      ],
    );

    await enterPlate(tester, 'NEW999');
    await scrollTo(tester, categoryField());
    await tester.tap(categoryField());
    await tester.pumpAndSettle();

    expect(find.text('Car · La categoría está llena'), findsOneWidget);
    expect(find.text('Motorcycle'), findsOneWidget);

    await tester.tap(find.text('Car · La categoría está llena'));
    await tester.pumpAndSettle();

    // A disabled item does not select anything, so the menu stays open.
    expect(find.text('Car · La categoría está llena'), findsOneWidget);
  });

  testWidgets('Success: renders the open sessions list and the check-in form', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.byTooltip('Escanear placa con la cámara'), findsOneWidget);
    expect(plateField(), findsOneWidget);
    expect(submitButton(), findsOneWidget);
    await scrollTo(tester, find.text('OPEN01'));
    expect(find.text('Vehículos dentro'), findsOneWidget);
    expect(find.text('OPEN01'), findsOneWidget);
  });

  testWidgets('Success: existing plate shows the read-only vehicle card', (
    tester,
  ) async {
    await pumpPage(tester);

    await enterPlate(tester, 'abc123');

    expect(find.text('Vehículo registrado'), findsOneWidget);
    expect(find.text('Car'), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
    expect(find.text('Mazda'), findsOneWidget);
    expect(categoryField(), findsNothing);
    expect(submitEnabled(tester), isTrue);

    await tapSubmit(tester);

    expect(checkIns.createCalls, 1);
    expect(checkIns.lastNewVehicle, isNull);
  });

  testWidgets('Success: submit resets the form, confirms and refocuses plate', (
    tester,
  ) async {
    await pumpPage(tester);
    await enterPlate(tester, 'abc123');

    await tapSubmit(tester);

    expect(find.text('Entrada registrada: ABC123'), findsOneWidget);
    expect(hapticFired(), isTrue);
    // The ticket with its exit QR and a print action is shown.
    expect(find.byType(QrCode), findsOneWidget);
    expect(find.text('Imprimir'), findsOneWidget);

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(plateField());
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
    // The plate is offered again for the next entry.
    expect(find.text('Repetir entrada ABC123'), findsOneWidget);
  });

  testWidgets('Success: the last plate can be repeated with one tap', (
    tester,
  ) async {
    final store = FakeKeyValueStore()
      ..values['preferences/last_plate'] = 'ABC123';
    serviceLocator.registerSingleton<KeyValueStore>(store);
    addTearDown(serviceLocator.reset);

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Repetir entrada ABC123'), findsOneWidget);
    await tester.tap(find.text('Repetir entrada ABC123'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(plateField()).controller!.text,
      'ABC123',
    );
  });

  testWidgets(
    'Success: a registered entry refreshes the vehicles-inside count',
    (tester) async {
      await pumpPage(tester);
      await enterPlate(tester, 'abc123');

      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      // One snapshot on open (for the capacity-aware category dropdown) plus
    // one refresh after the successful entry.
    expect(occupancy.occupancyCalls, 2);
    },
  );

  testWidgets(
    'Failure: a rejected entry leaves the vehicles-inside count untouched',
    (tester) async {
      await pumpPage(tester);
      await enterPlate(tester, 'abc123');
      checkIns.createError = const ValidationFailure(
        'Session already open for this plate',
      );

      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.text('Session already open for this plate'), findsOneWidget);
      // Only the snapshot taken when the page opened; a rejected entry never
    // refreshes occupancy.
    expect(occupancy.occupancyCalls, 1);
    },
  );

  testWidgets('Failure: an empty plate is validated inline, never sent', (
    tester,
  ) async {
    await pumpPage(tester);

    await tapSubmit(tester);

    expect(find.text('Ingresa la placa'), findsOneWidget);
    expect(checkIns.createCalls, 0);
  });

  testWidgets(
    'Failure: unknown plate shows registration fields and disables submit until a category is picked',
    (tester) async {
      await pumpPage(tester);

      await enterPlate(tester, 'XYZ999');

      expect(find.text('Vehículo nuevo'), findsOneWidget);
      expect(categoryField(), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Color (opcional)'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Marca (opcional)'),
        findsOneWidget,
      );
      expect(submitEnabled(tester), isFalse);
    },
  );

  testWidgets(
    'Security: new-vehicle data is sent only after picking a category, with blanks dropped',
    (tester) async {
      await pumpPage(tester);
      await enterPlate(tester, 'XYZ999');

      await tester.tap(categoryField());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Motorcycle').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Color (opcional)'),
        '  Blue ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Marca (opcional)'),
        '   ',
      );
      await tester.pump();

      expect(submitEnabled(tester), isTrue);
      await tester.ensureVisible(submitButton());
      await tester.pumpAndSettle();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(checkIns.lastPlate, 'XYZ999');
      expect(
        checkIns.lastNewVehicle,
        const NewVehicleInfo(categoryId: 2, color: 'Blue'),
      );
      expect(find.text('Vehículo nuevo'), findsNothing);
    },
  );

  testWidgets('Success: scanning fills the plate inline and keeps the photo', (
    tester,
  ) async {
    await pumpPage(tester, photos: true);

    await tester.tap(find.byTooltip('Escanear placa con la cámara'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(plateField()).controller!.text, 'ABC123');
    expect(find.text('Vehículo registrado'), findsOneWidget);
    expect(find.text('Fotos de evidencia (1/5)'), findsOneWidget);
    expect(hapticFired(), isTrue);
  });

  testWidgets('Failure: unreadable plate keeps the photo and asks to type', (
    tester,
  ) async {
    await pumpPage(
      tester,
      photos: true,
      scanner: _FakeScanner(
        error: const ValidationFailure('x', ClientFailureCodes.ocrNoText),
      ),
    );

    await tester.tap(find.byTooltip('Escanear placa con la cámara'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo leer la placa en la foto'), findsOneWidget);
    expect(find.text('Fotos de evidencia (1/5)'), findsOneWidget);
    final field = tester.widget<TextField>(plateField());
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('Success: captured photos are attached to the check-in', (
    tester,
  ) async {
    await pumpPage(tester, photos: true);
    await enterPlate(tester, 'abc123');

    await tester.tap(find.byTooltip('Agregar foto'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(submitButton());
    await tapSubmit(tester);

    expect(checkIns.lastPhotos, hasLength(1));
  });

  testWidgets(
    'Failure: the add-photo button is disabled at the 5-photo limit',
    (tester) async {
      await pumpPage(tester, photos: true);

      for (var i = 0; i < 5; i++) {
        await tester.ensureVisible(find.byTooltip('Agregar foto'));
        await tester.tap(find.byTooltip('Agregar foto'));
        await tester.pumpAndSettle();
      }

      final addButton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.byIcon(Icons.add_a_photo_outlined),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(addButton.onPressed, isNull);
      expect(find.text('Máximo 5 fotos por entrada'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(5));
      expect(find.byTooltip('Quitar foto'), findsNWidgets(5));
    },
  );

  testWidgets('Security: without scanner support the scan button is hidden', (
    tester,
  ) async {
    await pumpPage(tester, canScan: false);

    expect(find.byTooltip('Escanear placa con la cámara'), findsNothing);
    expect(plateField(), findsOneWidget);
  });

  testWidgets('A11y: 48dp targets, labels and contrast on the check-in form', (
    tester,
  ) async {
    await pumpPage(tester, photos: true);
    await tester.tap(find.byTooltip('Agregar foto'));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('Success: an initial plate is prefilled and looked up', (
    tester,
  ) async {
    await pumpPage(tester, initialPlate: 'abc123');

    expect(tester.widget<TextField>(plateField()).controller!.text, 'abc123');
    expect(find.text('Vehículo registrado'), findsOneWidget);
  });

  testWidgets('Success: the plate is normalized to uppercase without spaces', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(plateField(), 'ab 123');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(plateField()).controller!.text, 'AB123');
  });

  testWidgets('Security: the plate field cannot exceed the column width', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(plateField(), 'A' * 25);
    await tester.pump();

    expect(
      tester.widget<TextField>(plateField()).controller!.text,
      'A' * 20,
    );
  });

  testWidgets('Success: a plate already inside is flagged before submitting', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(plateField(), 'open01');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.textContaining('ya figura dentro'), findsOneWidget);
  });

  testWidgets('Failure: an unknown plate has no duplicate warning', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(plateField(), 'ZZZ999');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.textContaining('ya figura dentro'), findsNothing);
  });

  testWidgets('Success: vehicles inside collapse and can be marked for exit', (
    tester,
  ) async {
    String? marked;
    await pumpPage(tester, onMarkExit: (_, plate) => marked = plate);

    expect(find.text('OPEN01'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sessions_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('OPEN01'), findsNothing);

    await tester.tap(find.byKey(const Key('sessions_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('OPEN01'), findsOneWidget);

    await tester.tap(find.byTooltip('Marcar salida'));
    await tester.pumpAndSettle();
    expect(marked, 'OPEN01');
  });

  testWidgets('Success: the keys switch travels with the check-in', (
    tester,
  ) async {
    await pumpPage(tester);
    await enterPlate(tester, 'abc123');

    await tester.ensureVisible(find.byKey(const Key('check_in_left_keys')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check_in_left_keys')));
    await tester.pump();
    await tapSubmit(tester);

    expect(checkIns.lastLeftKeys, isTrue);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    // A fresh entry starts unchecked.
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('check_in_left_keys'))).value,
      isFalse,
    );
  });

  testWidgets('Success: a full car group disables every car category', (
    tester,
  ) async {
    await pumpPage(
      tester,
      occupancyCategories: const [
        CategoryOccupancySnapshot(
          categoryId: 1,
          name: 'Car',
          count: 4,
          capacity: 0,
          isFull: false,
        ),
        CategoryOccupancySnapshot(
          categoryId: 2,
          name: 'Motorcycle',
          count: 0,
          capacity: 0,
          isFull: false,
        ),
      ],
      space: const CapacitySnapshot(carOpen: 4, carCapacity: 4),
    );

    await enterPlate(tester, 'NEW999');
    await scrollTo(tester, categoryField());
    await tester.tap(categoryField());
    await tester.pumpAndSettle();

    expect(find.text('Car · La categoría está llena'), findsOneWidget);
    expect(find.text('Motorcycle'), findsOneWidget);
  });

  testWidgets('Success: category options show the remaining spaces', (
    tester,
  ) async {
    await pumpPage(
      tester,
      space: const CapacitySnapshot(
        carOpen: 1,
        carCapacity: 4,
        carReserved: 1,
      ),
    );

    await enterPlate(tester, 'NEW999');
    await scrollTo(tester, categoryField());
    await tester.tap(categoryField());
    await tester.pumpAndSettle();

    expect(find.text('Car · quedan 2'), findsOneWidget);
    // Motorcycles have no configured limit, so the option stays plain.
    expect(find.text('Motorcycle'), findsOneWidget);
  });

  testWidgets('Success: an active hold can be cancelled from check-in', (
    tester,
  ) async {
    final holds = FakeReservationRepository([
      sampleReservation(plate: 'OPEN01'),
    ]);
    await pumpPage(tester, reservations: holds);

    await enterPlate(tester, 'open01');
    expect(find.text('Reserva activa'), findsOneWidget);

    await tester.tap(find.text('Cancelar reserva'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar reserva'));
    await tester.pumpAndSettle();

    expect(holds.cancelledId, 1);
    expect(find.text('Reserva activa'), findsNothing);
    expect(find.text('Reserva cancelada'), findsOneWidget);
  });

  testWidgets('Success: two letters suggest a known plate', (tester) async {
    await pumpPage(tester, knownPlates: ['ABC123', 'ABX999']);

    await enterPlate(tester, 'AB');

    expect(find.widgetWithText(ActionChip, 'ABC123'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'ABX999'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'ABC123'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('ABC123'), findsWidgets);
    expect(find.widgetWithText(ActionChip, 'ABC123'), findsNothing);
  });

  testWidgets('Failure: a single letter does not suggest plates', (
    tester,
  ) async {
    await pumpPage(tester, knownPlates: ['ABC123']);

    await enterPlate(tester, 'A');

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('Security: suggestions stay off without a repository', (
    tester,
  ) async {
    await pumpPage(tester, knownPlates: const ['ABC123'],
        withVehicles: false);

    await enterPlate(tester, 'ABC');

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('Success: out-of-service spots reduce the remaining spaces', (
    tester,
  ) async {
    await pumpPage(
      tester,
      space: const CapacitySnapshot(carCapacity: 4, carOutOfService: 2),
    );

    await enterPlate(tester, 'NEW998');
    await scrollTo(tester, categoryField());
    await tester.tap(categoryField());
    await tester.pumpAndSettle();

    expect(find.text('Car · quedan 2'), findsOneWidget);
  });

  testWidgets('Success: the on-screen keypad fills the plate', (tester) async {
    await pumpPage(tester);

    final keypadButton = find.byTooltip('Teclado en pantalla');
    await tester.ensureVisible(keypadButton);
    await tester.pumpAndSettle();
    await tester.tap(keypadButton);
    await tester.pumpAndSettle();

    for (final key in ['A', 'B', 'C', '1', '2', '3']) {
      await tester.tap(find.widgetWithText(OutlinedButton, key));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('ABC123'), findsWidgets);
  });

  testWidgets('Success: the picker offers the group bays and sends one', (
    tester,
  ) async {
    await pumpPage(
      tester,
      board: const SlotBoard(
        spots: [
          ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
          ParkingSpot(id: 2, code: 'A2', group: SlotGroup.car, row: 0, col: 1),
          ParkingSpot(id: 3, code: 'A3', group: SlotGroup.car, row: 1, col: 0, active: false),
        ],
      ),
    );

    await enterPlate(tester, 'ABC123');
    expect(find.widgetWithText(ChoiceChip, 'Automático (primer libre)'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
    // Out of service is drawn but cannot be picked.
    expect(find.text('A3'), findsOneWidget);
    expect(find.text('Mant.'), findsOneWidget);

    await tester.tap(find.text('A3'));
    await tester.pump();
    expect(find.text('Espacio A3'), findsNothing);

    await tester.tap(find.text('A2'));
    await tester.pump();
    expect(find.text('Espacio A2'), findsOneWidget);
    await tapSubmit(tester);

    expect(checkIns.lastSpotId, 2);
  });

  testWidgets('Success: automatic keeps the first free spot', (tester) async {
    await pumpPage(
      tester,
      board: const SlotBoard(
        spots: [
          ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
        ],
      ),
    );

    await enterPlate(tester, 'ABC123');
    await tapSubmit(tester);

    expect(checkIns.lastSpotId, isNull);
  });
}
