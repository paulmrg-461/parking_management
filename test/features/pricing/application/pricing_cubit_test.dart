import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/pricing/application/pricing_cubit.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_rule.dart';
import 'package:parking_management/features/pricing/domain/entities/pricing_settings.dart';

import '../../../helpers/fake_pricing_repository.dart';

void main() {
  PricingLoaded loaded(PricingCubit cubit) => cubit.state as PricingLoaded;

  test('Success: load emits loading then the rules and settings', () async {
    final cubit = PricingCubit(FakePricingRepository());
    final states = <PricingState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<PricingLoading>());
    expect(loaded(cubit).rules, hasLength(1));
    expect(loaded(cubit).settings.enabled, isTrue);
    await subscription.cancel();
    await cubit.close();
  });

  test('Success: an empty list is a loaded state', () async {
    final cubit = PricingCubit(FakePricingRepository(rules: []));
    await cubit.load();
    expect(loaded(cubit).rules, isEmpty);
    await cubit.close();
  });

  test('Failure: a load error emits Failure', () async {
    final cubit = PricingCubit(
      FakePricingRepository()..loadError = const NetworkFailure('offline'),
    );
    await cubit.load();
    expect(cubit.state, isA<PricingFailure>());
    await cubit.close();
  });

  test('Success: saveRule refreshes the list', () async {
    final repository = FakePricingRepository();
    final cubit = PricingCubit(repository);
    await cubit.load();

    await cubit.saveRule(
      const PricingRuleDraft(name: 'Nueva', multiplierBps: 12000),
    );

    expect(loaded(cubit).submission, isA<SubmissionSucceeded<PricingRule>>());
    expect(loaded(cubit).rules.any((rule) => rule.name == 'Nueva'), isTrue);
    await cubit.close();
  });

  test('Failure: a duplicate keeps the list and reports it', () async {
    final repository = FakePricingRepository()
      ..writeError = const ValidationFailure(
        'DuplicatePricingRuleError',
        'DuplicatePricingRuleError',
      );
    final cubit = PricingCubit(repository);
    await cubit.load();

    await cubit.saveRule(const PricingRuleDraft(name: 'Alta ocupacion'));

    expect(loaded(cubit).submission, isA<SubmissionFailed>());
    expect(loaded(cubit).rules, hasLength(1));
    await cubit.close();
  });

  test('Success: toggleRule saves the opposite active flag', () async {
    final repository = FakePricingRepository();
    final cubit = PricingCubit(repository);
    await cubit.load();
    final rule = loaded(cubit).rules.single;

    await cubit.toggleRule(rule);

    expect(repository.saved.single.active, isFalse);
    await cubit.close();
  });

  test('Success: deleteRule removes the row locally', () async {
    final repository = FakePricingRepository();
    final cubit = PricingCubit(repository);
    await cubit.load();

    await cubit.deleteRule(loaded(cubit).rules.single.id);

    expect(repository.deleted, [1]);
    expect(loaded(cubit).rules, isEmpty);
    await cubit.close();
  });

  test('Success: saveSettings updates the state', () async {
    final repository = FakePricingRepository();
    final cubit = PricingCubit(repository);
    await cubit.load();

    await cubit.saveSettings(
      const PricingSettings(
        enabled: true,
        floorBps: 9000,
        ceilingBps: 20000,
        roundTo: 100,
      ),
    );

    expect(loaded(cubit).settings.ceilingBps, 20000);
    expect(repository.settingsSaves, 1);
    await cubit.close();
  });
}
