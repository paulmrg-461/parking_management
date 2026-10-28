import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/evidence/application/evidence_cubit.dart';
import 'package:parking_management/features/evidence/domain/entities/public_evidence.dart';
import 'package:parking_management/features/evidence/presentation/public_evidence_page.dart';

import '../../../helpers/fake_evidence_repository.dart';
import '../../../helpers/test_app.dart';

Future<void> pumpPage(
  WidgetTester tester,
  FakeEvidenceRepository repository, {
  int? sessionId = 43,
  String? plate = 'ABC123',
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cubit = EvidenceCubit(repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider<EvidenceCubit>.value(
        value: cubit,
        child: PublicEvidencePage(sessionId: sessionId, plate: plate),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Success: lists the photos and videos behind the plate', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeEvidenceRepository(
        evidence: PublicEvidence(
          plate: 'ABC123',
          entryTime: DateTime(2026, 10, 28, 8),
          photos: [
            EvidenceMedia(url: 'https://x/1.jpg', takenAt: DateTime(2026)),
            EvidenceMedia(url: 'https://x/2.jpg', takenAt: DateTime(2026)),
          ],
          videos: [
            EvidenceMedia(
              url: 'https://x/1.mp4',
              takenAt: DateTime(2026),
              durationSeconds: 42,
            ),
          ],
        ),
      ),
    );

    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Clave de acceso: ABC123'), findsOneWidget);
    expect(find.text('Fotos (2)'), findsOneWidget);
    expect(find.text('Videos (1)'), findsOneWidget);
    expect(find.text('Ver video'), findsOneWidget);
  });

  testWidgets('Failure: a wrong or incomplete link explains the key', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeEvidenceRepository(),
      sessionId: null,
      plate: null,
    );

    expect(
      find.text('Este enlace no es válido o la placa no coincide.'),
      findsOneWidget,
    );
  });

  testWidgets('Success: an empty session shows the empty state', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeEvidenceRepository(
        evidence: PublicEvidence(
          plate: 'ABC123',
          entryTime: DateTime(2026, 10, 28, 8),
        ),
      ),
    );

    expect(find.text('Este ingreso no tiene fotos ni videos.'), findsOneWidget);
  });
}
