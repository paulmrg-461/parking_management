import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/loyalty/application/loyalty_admin_cubit.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_account.dart';
import 'package:parking_management/features/loyalty/domain/entities/loyalty_settings.dart';

import '../../../helpers/fake_loyalty_repository.dart';

void main() {
  LoyaltyAdminLoaded loaded(LoyaltyAdminCubit cubit) =>
      cubit.state as LoyaltyAdminLoaded;

  test('Success: load emits loading then loaded', () async {
    final cubit = LoyaltyAdminCubit(FakeLoyaltyRepository());
    final states = <LoyaltyAdminState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load();

    expect(states.first, isA<LoyaltyAdminLoading>());
    expect(loaded(cubit).accounts, hasLength(1));
    expect(loaded(cubit).settings.enabled, isTrue);
    await subscription.cancel();
    await cubit.close();
  });

  test('Failure: a load error emits failure', () async {
    final cubit = LoyaltyAdminCubit(
      FakeLoyaltyRepository()..loadError = const NetworkFailure('offline'),
    );
    await cubit.load();
    expect(cubit.state, isA<LoyaltyAdminFailure>());
    await cubit.close();
  });

  test('Success: save updates the settings', () async {
    final repository = FakeLoyaltyRepository();
    final cubit = LoyaltyAdminCubit(repository);
    await cubit.load();

    await cubit.save(
      const LoyaltySettings(
        enabled: true,
        visitsRequired: 6,
        rewardKind: LoyaltyRewardKind.fixedAmount,
        rewardFixedAmount: 2000,
      ),
    );

    expect(loaded(cubit).settings.visitsRequired, 6);
    expect(loaded(cubit).submission, isA<SubmissionSucceeded>());
    expect(repository.settingsSaves, 1);
    await cubit.close();
  });

  test('Failure: a save error keeps the data and reports it', () async {
    final repository = FakeLoyaltyRepository()
      ..writeError = const ValidationFailure(
        'InvalidLoyaltySettingsError',
        'InvalidLoyaltySettingsError',
      );
    final cubit = LoyaltyAdminCubit(repository);
    await cubit.load();

    await cubit.save(const LoyaltySettings(visitsRequired: 1));

    expect(loaded(cubit).submission, isA<SubmissionFailed>());
    expect(loaded(cubit).accounts, hasLength(1));
    await cubit.close();
  });

  test('Success: adjust refreshes the accounts', () async {
    final repository = FakeLoyaltyRepository();
    final cubit = LoyaltyAdminCubit(repository);
    await cubit.load();

    await cubit.adjust(plate: 'ABC123', delta: 1, reason: 'Ajuste');

    expect(repository.adjustCalls, 1);
    expect(repository.lastAdjust?.plate, 'ABC123');
    expect(repository.accountsCalls, greaterThanOrEqualTo(2));
    expect(loaded(cubit).submission, isA<SubmissionSucceeded>());
    await cubit.close();
  });

  test('Security: an operator adjust reports AdminRequiredError', () async {
    final repository = FakeLoyaltyRepository()
      ..writeError = const ValidationFailure(
        'AdminRequiredError',
        'AdminRequiredError',
      );
    final cubit = LoyaltyAdminCubit(repository);
    await cubit.load();

    await cubit.adjust(plate: 'ABC123', delta: 1, reason: 'Ajuste');

    final submission = loaded(cubit).submission;
    expect(submission, isA<SubmissionFailed>());
    expect(
      (submission as SubmissionFailed).failure?.code,
      'AdminRequiredError',
    );
    await cubit.close();
  });

  test('Success: empty accounts keeps the loaded state', () async {
    final cubit = LoyaltyAdminCubit(
      FakeLoyaltyRepository(accounts: const <LoyaltyAccount>[]),
    );
    await cubit.load();
    expect(loaded(cubit).accounts, isEmpty);
    await cubit.close();
  });

  test('Success: the report loads for the requested window', () async {
    final repository = FakeLoyaltyRepository();
    final cubit = LoyaltyAdminCubit(repository);
    await cubit.load();

    await cubit.loadReport(DateTime(2026, 11, 1), DateTime(2026, 11, 30));

    expect(repository.reportCalls, 1);
    expect(loaded(cubit).report?.members, 12);
    await cubit.close();
  });
}
