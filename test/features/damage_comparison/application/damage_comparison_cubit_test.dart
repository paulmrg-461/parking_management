import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/damage_comparison/application/damage_comparison_cubit.dart';
import 'package:parking_management/features/damage_comparison/domain/entities/damage_comparison.dart';

import '../../../helpers/fake_damage_repository.dart';

void main() {
  DamageLoaded loaded(DamageComparisonCubit cubit) =>
      cubit.state as DamageLoaded;

  test('load emits loaded with the view', () async {
    final cubit = DamageComparisonCubit(
      FakeDamageRepository(view: sampleDamageView()),
      sessionId: 1,
    );
    await cubit.load();
    expect(loaded(cubit).view.comparison?.overall, DamageOverall.possible);
    await cubit.close();
  });

  test('not configured emits the not configured state', () async {
    final cubit = DamageComparisonCubit(
      FakeDamageRepository(ai: const DamageAiStatus(configured: false)),
      sessionId: 1,
    );
    await cubit.load();
    expect(cubit.state, isA<DamageNotConfigured>());
    await cubit.close();
  });

  test('load failure emits failure', () async {
    final cubit = DamageComparisonCubit(
      FakeDamageRepository()..loadError = const NetworkFailure('offline'),
      sessionId: 1,
    );
    await cubit.load();
    expect(cubit.state, isA<DamageFailure>());
    await cubit.close();
  });

  test('run calls the repository and keeps the view', () async {
    final repository = FakeDamageRepository(view: sampleDamageView());
    final cubit = DamageComparisonCubit(repository, sessionId: 1);
    await cubit.load();
    await cubit.run();
    expect(repository.runCalls, 1);
    expect(loaded(cubit).running, isFalse);
    await cubit.close();
  });

  test('review without a note is rejected locally', () async {
    final repository = FakeDamageRepository(view: sampleDamageView());
    final cubit = DamageComparisonCubit(repository, sessionId: 1);
    await cubit.load();
    await cubit.review(3, FindingReview.confirmed, 'ab');
    expect(repository.reviewCalls, 0);
    expect(loaded(cubit).failure, isA<ValidationFailure>());
    await cubit.close();
  });

  test('review updates the finding', () async {
    final repository = FakeDamageRepository(view: sampleDamageView());
    final cubit = DamageComparisonCubit(repository, sessionId: 1);
    await cubit.load();
    await cubit.review(3, FindingReview.confirmed, 'Verificado');
    expect(repository.reviewCalls, 1);
    expect(loaded(cubit).view.comparison?.findings.single.reviewStatus,
        FindingReview.confirmed);
    await cubit.close();
  });
}
