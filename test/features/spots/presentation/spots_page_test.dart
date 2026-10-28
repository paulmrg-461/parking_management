import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/spots/application/spots_cubit.dart';
import 'package:parking_management/features/spots/domain/entities/parking_spot.dart';
import 'package:parking_management/features/spots/presentation/spots_page.dart';

import '../../../helpers/fake_spot_repository.dart';
import '../../../helpers/test_app.dart';

Future<SpotsCubit> pumpPage(
  WidgetTester tester,
  FakeSpotRepository repository, {
  bool isAdmin = true,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = SpotsCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<SpotsCubit>.value(
        value: cubit,
        child: SpotsPage(isAdmin: isAdmin),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

FakeSpotRepository sampleRepository() => FakeSpotRepository(const [
  ParkingSpot(id: 1, code: 'A1', group: SlotGroup.car, row: 0, col: 0),
  ParkingSpot(id: 2, code: 'A2', group: SlotGroup.car, row: 0, col: 1),
]);

void main() {
  testWidgets('Success: the editor paints the bays', (tester) async {
    await pumpPage(tester, sampleRepository());

    expect(find.text('A1'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
    expect(find.text('Mapa del parqueadero'), findsOneWidget);
  });

  testWidgets('Failure: only admins see the editor controls', (tester) async {
    await pumpPage(tester, sampleRepository(), isAdmin: false);

    expect(
      find.text('Solo un administrador puede editar el mapa'),
      findsOneWidget,
    );
    expect(find.text('Agregar espacio'), findsNothing);
  });

  testWidgets('Success: adding a spot takes the first free cell', (
    tester,
  ) async {
    final repository = sampleRepository();
    await pumpPage(tester, repository);

    await tester.tap(find.text('Agregar espacio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('spot_code')), 'A3');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.spots, hasLength(3));
    final added = repository.spots.last;
    expect(added.code, 'A3');
    expect(added.row, 0);
    expect(added.col, 2);
  });

  testWidgets('Success: tapping a bay edits its code', (tester) async {
    final repository = sampleRepository();
    await pumpPage(tester, repository);

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('spot_edit_code')), 'B1');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.spots.first.code, 'B1');
  });

  testWidgets('Success: dragging a bay moves it on the grid', (tester) async {
    final repository = sampleRepository();
    await pumpPage(tester, repository);

    final start = tester.getCenter(find.text('A1'));
    final target = tester.getCenter(find.text('2-2'));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    final moved = repository.spots.firstWhere((spot) => spot.code == 'A1');
    expect(moved.row, 1);
    expect(moved.col, 1);
  });
}
