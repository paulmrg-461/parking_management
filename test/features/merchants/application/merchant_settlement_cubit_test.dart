import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/merchants/application/merchant_settlement_cubit.dart';

import '../../../helpers/fake_merchant_repository.dart';

void main() {
  test('Success: load emits Loading then Loaded', () async {
    final cubit = MerchantSettlementCubit(FakeMerchantRepository());
    final states = <MerchantSettlementState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load(start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 30));
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<MerchantSettlementLoading>());
    expect(cubit.state, isA<MerchantSettlementLoaded>());
    await subscription.cancel();
    await cubit.close();
  });

  test('Failure: a failed load emits Failure and retry reloads', () async {
    final repository = FakeMerchantRepository()
      ..listError = const NetworkFailure('offline');
    final cubit = MerchantSettlementCubit(repository);
    await cubit.load(start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 30));
    expect(cubit.state, isA<MerchantSettlementFailure>());

    repository.listError = null;
    await cubit.retry();
    expect(cubit.state, isA<MerchantSettlementLoaded>());
    await cubit.close();
  });
}
