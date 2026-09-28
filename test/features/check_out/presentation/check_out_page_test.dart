import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/check_out/application/check_out_cubit.dart';
import 'package:parking_management/features/check_out/application/check_out_vehicle.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';
import 'package:parking_management/features/check_out/presentation/check_out_page.dart';
import 'package:parking_management/features/vehicles/domain/entities/vehicle.dart';

import '../../../helpers/fake_vehicle_repository.dart';

class _FakeCheckOutRepository implements CheckOutRepository {
  Failure? checkOutError;

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
  }) async => PagedResult([
    OpenSession(id: 1, vehicleId: 1, entryTime: DateTime(2026, 1, 1)),
    OpenSession(id: 2, vehicleId: 2, entryTime: DateTime(2026, 1, 1)),
  ]);

  @override
  Future<CheckOutReceipt> checkOut(int sessionId) async =>
      throw checkOutError ?? UnimplementedError();
}

void main() {
  late _FakeCheckOutRepository repository;

  Future<void> pumpPage(WidgetTester tester) async {
    repository = _FakeCheckOutRepository();
    final vehicles = FakeVehicleRepository(const [
      Vehicle(id: 1, plate: 'ABC123', categoryId: 1),
      Vehicle(id: 2, plate: 'XYZ999', categoryId: 1),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CheckOutCubit>(
          create: (_) => CheckOutCubit(
            CheckOutVehicle(repository),
            repository,
            vehicles,
            searchDebounce: Duration.zero,
          ),
          child: const CheckOutPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Success: renders the open sessions list resolved to plates', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('XYZ999'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Check out'), findsNWidgets(2));
    expect(find.text('Search by plate'), findsOneWidget);
  });

  testWidgets('Success: searching filters the list through the cubit', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();

    expect(find.text('ABC123'), findsNothing);
    expect(find.text('XYZ999'), findsOneWidget);
  });

  testWidgets(
    'Failure: a failed check-out keeps the list and shows a SnackBar',
    (tester) async {
      await pumpPage(tester);
      repository.checkOutError = const ValidationFailure(
        'Session already closed',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Check out').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Session already closed'), findsOneWidget);
      expect(find.text('ABC123'), findsOneWidget);
    },
  );
}
