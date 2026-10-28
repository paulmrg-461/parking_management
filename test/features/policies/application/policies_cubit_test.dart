import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/policies/application/policies_cubit.dart';
import 'package:parking_management/features/policies/domain/entities/lot_profile.dart';

import '../../../helpers/fake_policy_repository.dart';

void main() {
  test('Success: loads the public profile of the lot', () async {
    final repository = FakePolicyRepository(
      profile: const LotProfile(
        id: 1,
        name: 'Parqueadero DevPaul',
        legalPolicy: 'Texto legal',
      ),
    );
    final cubit = PoliciesCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(1);

    expect(cubit.state.status, PoliciesStatus.loaded);
    expect(cubit.state.profile?.name, 'Parqueadero DevPaul');
    expect(repository.lastLot, 1);
  });

  test('Failure: an invalid lot never calls the server', () async {
    final repository = FakePolicyRepository();
    final cubit = PoliciesCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(null);

    expect(cubit.state.status, PoliciesStatus.failure);
    expect(repository.calls, 0);
  });

  test('Security: a server failure keeps the error state', () async {
    final repository = FakePolicyRepository(
      error: const ValidationFailure('nope', 'PolicyNotFoundError'),
    );
    final cubit = PoliciesCubit(repository);
    addTearDown(cubit.close);

    await cubit.load(1);

    expect(cubit.state.status, PoliciesStatus.failure);
    expect(cubit.state.failure?.code, 'PolicyNotFoundError');
  });
}
