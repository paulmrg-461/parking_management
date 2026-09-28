import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/categories/domain/entities/category.dart';
import 'package:parking_management/features/categories/domain/repositories/category_repository.dart';
import 'package:parking_management/features/check_in/application/check_in_cubit.dart';
import 'package:parking_management/features/check_in/application/create_check_in.dart';
import 'package:parking_management/features/check_in/application/vehicle_lookup_cubit.dart';
import 'package:parking_management/features/check_in/domain/entities/new_vehicle_info.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:parking_management/features/check_in/presentation/check_in_page.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/plate_scanning/application/plate_scanning_cubit.dart';
import 'package:parking_management/features/plate_scanning/domain/entities/plate_scan_result.dart';
import 'package:parking_management/features/plate_scanning/domain/repositories/plate_image_capture.dart';
import 'package:parking_management/features/plate_scanning/domain/repositories/plate_scanner.dart';
import 'package:parking_management/features/vehicles/domain/commands/create_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/commands/update_vehicle_command.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';
import 'package:parking_management/features/vehicles/domain/repositories/vehicle_repository.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_png.dart';

class _FakeCheckInRepository implements CheckInRepository {
  int createCalls = 0;
  String? lastPlate;
  NewVehicleInfo? lastNewVehicle;
  List<XFile> lastPhotos = const [];

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
  }) async {
    createCalls++;
    lastPlate = plate;
    lastNewVehicle = newVehicle;
    lastPhotos = photos;
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
  }) => throw UnimplementedError();

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
  }) async {
    checkIns = _FakeCheckInRepository();
    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider<CheckInCubit>(
              create: (_) => CheckInCubit(CreateCheckIn(checkIns), checkIns),
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

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(checkIns.createCalls, 1);
    expect(checkIns.lastNewVehicle, isNull);
  });

  testWidgets('Success: submit resets the form, confirms and refocuses plate', (
    tester,
  ) async {
    await pumpPage(tester);
    await enterPlate(tester, 'abc123');

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(find.text('Entrada registrada: ABC123'), findsOneWidget);
    final field = tester.widget<TextField>(plateField());
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(hapticFired(), isTrue);
  });

  testWidgets('Failure: an empty plate is validated inline, never sent', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

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
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

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
}
