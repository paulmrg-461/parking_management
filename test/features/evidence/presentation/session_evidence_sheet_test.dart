import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/evidence/domain/entities/session_evidence.dart';
import 'package:parking_management/features/evidence/presentation/session_evidence_sheet.dart';

import '../../../helpers/fake_session_evidence_repository.dart';
import '../../../helpers/test_app.dart';

Future<FakeSessionEvidenceRepository> _pump(
  WidgetTester tester, {
  List<SessionEvidence> items = const [],
  Failure? error,
}) async {
  final repository = FakeSessionEvidenceRepository(items)..error = error;
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: SessionEvidenceSheet(
          sessionId: 2,
          plate: 'ABC123',
          repository: repository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('Success: photos and videos are listed with their labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      items: [
        SessionEvidence(
          id: 1,
          path: 'p1/0.jpg',
          kind: EvidenceKind.photo,
          takenAt: DateTime(2026, 11, 9, 10),
        ),
        SessionEvidence(
          id: 2,
          path: 'p1/1.mp4',
          kind: EvidenceKind.video,
          durationSeconds: 42,
          takenAt: DateTime(2026, 11, 9, 10, 1),
        ),
      ],
    );

    expect(find.text('Evidencias de ABC123'), findsOneWidget);
    expect(find.bySemanticsLabel('Foto 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Video de 42 s'), findsOneWidget);
    expect(find.text('42 s'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Empty: a session without evidence says so', (tester) async {
    await _pump(tester);

    expect(find.text('Sin fotos ni videos para esta sesión'), findsOneWidget);
  });

  testWidgets('Failure: a failed load offers a retry', (tester) async {
    final repository = await _pump(
      tester,
      error: const NetworkFailure('offline'),
    );

    expect(find.text('No hay conexión con el servidor'), findsOneWidget);

    repository.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Sin fotos ni videos para esta sesión'), findsOneWidget);
    expect(repository.calls, 2);
  });
}
