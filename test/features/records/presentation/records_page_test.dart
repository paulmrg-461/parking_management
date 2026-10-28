import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/records/application/records_cubit.dart';
import 'package:parking_management/features/records/presentation/records_page.dart';

import '../../../helpers/fake_record_repository.dart';
import '../../../helpers/test_app.dart';

Future<RecordsCubit> pumpPage(
  WidgetTester tester,
  FakeRecordRepository repository, {
  void Function(BuildContext, String)? onOpenHistory,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = RecordsCubit(repository, searchDebounce: Duration.zero);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<RecordsCubit>.value(
        value: cubit,
        child: RecordsPage(onOpenHistory: onOpenHistory),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  testWidgets('Success: the log lists entries and exits', (tester) async {
    await pumpPage(
      tester,
      FakeRecordRepository([
        sampleRecord(id: 1, plate: 'ABC123'),
        sampleRecord(
          id: 2,
          plate: 'LCR481',
          status: 'open',
          amountCharged: 0,
          durationSeconds: 1800,
        ),
      ]),
    );

    expect(find.text('2 registros'), findsOneWidget);
    expect(find.text('ABC123'), findsNWidgets(2));
    expect(find.text('LCR481'), findsOneWidget);
    expect(find.text('Dentro'), findsWidgets);
    expect(find.textContaining('5.000'), findsOneWidget);
  });

  testWidgets('Success: filtering by plate asks the server', (tester) async {
    final repository = FakeRecordRepository([
      sampleRecord(id: 1, plate: 'ABC123'),
      sampleRecord(id: 2, plate: 'LCR481'),
    ]);
    await pumpPage(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextField, 'Placa'),
      'LCR',
    );
    await tester.pumpAndSettle();

    expect(repository.lastPlate, 'LCR');
    expect(find.text('1 registros'), findsOneWidget);
    expect(find.text('LCR481'), findsOneWidget);
    // The hint shows the sample plate; no record row remains.
    expect(find.text('\$2.500'), findsNothing);

    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();
    expect(find.text('2 registros'), findsOneWidget);
  });

  testWidgets('Success: tapping a record opens the vehicle history', (
    tester,
  ) async {
    String? opened;
    await pumpPage(
      tester,
      FakeRecordRepository([sampleRecord(id: 1, plate: 'ABC123')]),
      onOpenHistory: (_, plate) => opened = plate,
    );

    await tester.tap(find.text('ABC123').last);
    await tester.pumpAndSettle();

    expect(opened, 'ABC123');
  });

  testWidgets('Failure: an unknown plate shows the empty state', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeRecordRepository([sampleRecord(id: 1, plate: 'ABC123')]),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Placa'),
      'ZZZ',
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin registros para «ZZZ»'), findsOneWidget);
  });

  testWidgets('Success: a range preset filters the log', (tester) async {
    final repository = FakeRecordRepository([
      sampleRecord(id: 1, plate: 'ABC123', entryTime: DateTime.now()),
      sampleRecord(id: 2, plate: 'ABC124', entryTime: DateTime(2026, 1, 1)),
    ]);
    await pumpPage(tester, repository);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Hoy'));
    await tester.pumpAndSettle();

    expect(repository.lastFrom, isNotNull);
    expect(find.text('1 registros'), findsOneWidget);
    expect(find.text('ABC124'), findsNothing);
  });

  testWidgets('Success: copying the CSV confirms with a snack', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpPage(
      tester,
      FakeRecordRepository([sampleRecord(id: 1, plate: 'ABC123')]),
    );

    await tester.tap(find.byTooltip('Copiar CSV'));
    await tester.pumpAndSettle();

    expect(find.text('CSV copiado al portapapeles'), findsOneWidget);
  });

  testWidgets('Failure: exporting an empty filter asks for data', (
    tester,
  ) async {
    await pumpPage(tester, FakeRecordRepository());

    await tester.tap(find.byTooltip('Copiar CSV'));
    await tester.pumpAndSettle();

    expect(find.text('No hay registros para exportar'), findsOneWidget);
  });
}
