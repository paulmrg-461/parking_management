import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/policies/domain/entities/lot_profile.dart';
import 'package:parking_management/features/policies/domain/repositories/policy_repository.dart';

class FakePolicyRepository implements PolicyRepository {
  FakePolicyRepository({this.profile, this.error});

  LotProfile? profile;
  Failure? error;
  int calls = 0;
  int? lastLot;

  @override
  Future<LotProfile> fetch(int lotId) async {
    calls++;
    lastLot = lotId;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return profile ??
        LotProfile(
          id: lotId,
          name: 'Parqueadero',
          legalPolicy: 'Política de prueba',
        );
  }
}
