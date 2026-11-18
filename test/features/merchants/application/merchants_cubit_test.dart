import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/merchants/application/merchants_cubit.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant.dart';

import '../../../helpers/fake_merchant_repository.dart';

void main() {
  MerchantsLoaded loaded(MerchantsCubit cubit) =>
      cubit.state as MerchantsLoaded;

  test('Success: load emits loading then the list and policy', () async {
    final cubit = MerchantsCubit(FakeMerchantRepository(policy: 2));
    final states = <MerchantsState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<MerchantsLoading>());
    expect(loaded(cubit).merchants, hasLength(1));
    expect(loaded(cubit).maxPerSession, 2);
    await subscription.cancel();
    await cubit.close();
  });

  test('Failure: a failed load emits the failure state', () async {
    final cubit = MerchantsCubit(
      FakeMerchantRepository()..listError = const NetworkFailure('offline'),
    );
    await cubit.load();
    expect(cubit.state, isA<MerchantsFailure>());
    await cubit.close();
  });

  test('Success: create exposes the credentials once and refreshes', () async {
    final repository = FakeMerchantRepository()
      ..credentialsToReturn = const MerchantCredentials(
        merchantId: 9,
        pin: '123456',
        token: 'abc',
        linkPath: '/validate?m=abc',
      );
    final cubit = MerchantsCubit(repository);
    await cubit.load();

    await cubit.save(
      const MerchantDraft(
        name: 'Nuevo',
        kind: MerchantBenefitKind.fixedAmount,
        value: 5000,
      ),
    );

    expect(loaded(cubit).justCreated?.pin, '123456');
    expect(loaded(cubit).submission, isA<SubmissionSucceeded<Merchant>>());
    expect(loaded(cubit).merchants.any((m) => m.name == 'Nuevo'), isTrue);

    cubit.dismissCredentials();
    expect(loaded(cubit).justCreated, isNull);
    await cubit.close();
  });

  test('Failure: a duplicate name keeps the list and reports it', () async {
    final repository = FakeMerchantRepository()
      ..writeError = const ValidationFailure(
        'DuplicateMerchantError',
        'DuplicateMerchantError',
      );
    final cubit = MerchantsCubit(repository);
    await cubit.load();

    await cubit.save(
      const MerchantDraft(
        name: 'Cafe Uno',
        kind: MerchantBenefitKind.percentage,
        value: 10,
      ),
    );

    expect(loaded(cubit).submission, isA<SubmissionFailed>());
    expect(loaded(cubit).merchants, hasLength(1));
    await cubit.close();
  });

  test('Success: delete and policy update the state', () async {
    final repository = FakeMerchantRepository();
    final cubit = MerchantsCubit(repository);
    await cubit.load();

    await cubit.savePolicy(3);
    expect(loaded(cubit).maxPerSession, 3);
    expect(repository.policySaves, 1);

    await cubit.delete(1);
    expect(repository.deleted, [1]);
    expect(loaded(cubit).merchants, isEmpty);
    await cubit.close();
  });

  test('Failure: reset credentials reports errors without wiping the list', () async {
    final repository = FakeMerchantRepository()
      ..writeError = const ValidationFailure(
        'MerchantNotFoundError',
        'MerchantNotFoundError',
      );
    final cubit = MerchantsCubit(repository);
    await cubit.load();

    await cubit.resetCredentials(1, rotateToken: true);

    expect(loaded(cubit).submission, isA<SubmissionFailed>());
    expect(loaded(cubit).merchants, hasLength(1));
    await cubit.close();
  });
}
