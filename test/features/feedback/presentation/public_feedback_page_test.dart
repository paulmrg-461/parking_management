import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/feedback/application/public_feedback_cubit.dart';
import 'package:parking_management/features/feedback/domain/entities/feedback_invite.dart';
import 'package:parking_management/features/feedback/presentation/public_feedback_page.dart';

import '../../../helpers/fake_feedback_repository.dart';
import '../../../helpers/test_app.dart';

const _invite = FeedbackInvite(
  lotId: 1,
  lotName: 'Parqueadero Central',
  rateable: true,
  rated: false,
);

Future<FakeFeedbackRepository> _pump(
  WidgetTester tester, {
  FakeFeedbackRepository? repository,
  int? sessionId = 7,
  String? plate = 'ABC123',
  Size size = const Size(400, 900),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo =
      repository ?? (FakeFeedbackRepository()..inviteToReturn = _invite);
  final cubit = PublicFeedbackCubit(repo);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(
        value: cubit,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: PublicFeedbackPage(sessionId: sessionId, plate: plate),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('Success: the survey shows the lot and submits a rating', (
    tester,
  ) async {
    final repository = await _pump(tester);

    expect(find.text('¿Cómo fue tu visita a Parqueadero Central?'), findsOne);

    final submit = find.byKey(const Key('feedback-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.tap(find.byKey(const Key('feedback-star-4')));
    await tester.pump();
    expect(find.text('Buena'), findsOne);

    await tester.enterText(
      find.byKey(const Key('feedback_comment')),
      'Buen servicio',
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('¡Gracias por tu opinión!'), findsOne);
    expect(repository.lastRating, 4);
    expect(repository.lastComment, 'Buen servicio');
  });

  testWidgets('Success: an already rated visit shows the previous rating', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: FakeFeedbackRepository()
        ..inviteToReturn = const FeedbackInvite(
          lotId: 1,
          lotName: 'Central',
          rateable: true,
          rated: true,
          rating: 5,
        ),
    );

    expect(find.text('Ya calificaste esta visita'), findsOne);
    expect(find.byKey(const Key('feedback-submit')), findsNothing);
  });

  testWidgets('Failure: an unknown link is an informative empty state', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: FakeFeedbackRepository()..inviteToReturn = null,
    );

    expect(find.text('No encontramos esta visita'), findsOne);
  });

  testWidgets('Failure: an open session explains when it can be rated', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: FakeFeedbackRepository()
        ..inviteToReturn = const FeedbackInvite(
          lotId: 1,
          lotName: 'Central',
          rateable: false,
          rated: false,
        ),
    );

    expect(find.text('Tu visita sigue en curso'), findsOne);
  });

  testWidgets('Failure: a load error offers a retry that recovers', (
    tester,
  ) async {
    final repository = FakeFeedbackRepository()
      ..inviteError = const NetworkFailure();
    await _pump(tester, repository: repository);

    expect(find.text('No hay conexión con el servidor'), findsOne);

    repository
      ..inviteError = null
      ..inviteToReturn = _invite;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Cómo fue tu visita a Parqueadero Central?'), findsOne);
  });

  testWidgets('Failure: a failed submit keeps the answer and shows the error', (
    tester,
  ) async {
    final repository = FakeFeedbackRepository()
      ..inviteToReturn = _invite
      ..submitError = const NetworkFailure();
    await _pump(tester, repository: repository);

    await tester.tap(find.byKey(const Key('feedback-star-3')));
    await tester.enterText(
      find.byKey(const Key('feedback_comment')),
      'Falta limpieza',
    );
    await tester.tap(find.byKey(const Key('feedback-submit')));
    await tester.pumpAndSettle();

    expect(find.text('No hay conexión con el servidor'), findsOne);
    expect(find.text('Falta limpieza'), findsOne);
    expect(find.byKey(const Key('feedback-star-3')), findsOne);
  });

  testWidgets('Success: a link without plate asks for it before loading', (
    tester,
  ) async {
    final repository = await _pump(tester, plate: null);

    expect(find.text('Ingresa la placa para calificar tu visita'), findsOne);
    expect(repository.inviteCalls, 0);

    await tester.enterText(find.byKey(const Key('feedback_plate')), 'abc123');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(repository.inviteCalls, 1);
    expect(repository.lastInvitePlate, 'ABC123');
    expect(find.text('Tu calificación'), findsOne);
  });

  testWidgets('Success: the survey fits 360 dp with large text', (
    tester,
  ) async {
    await _pump(tester, size: const Size(360, 900), textScale: 1.6);

    expect(tester.takeException(), isNull);
    expect(find.text('Tu calificación'), findsOne);
  });

  testWidgets('Accessibility: buttons meet the tap target and label guides', (
    tester,
  ) async {
    await _pump(tester);

    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
