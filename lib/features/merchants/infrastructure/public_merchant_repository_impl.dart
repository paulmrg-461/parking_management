import '../domain/entities/merchant_portal.dart';
import '../domain/entities/merchant_validation_result.dart';
import '../domain/repositories/public_merchant_repository.dart';
import 'public_merchant_remote_data_source.dart';

class PublicMerchantRepositoryImpl implements PublicMerchantRepository {
  PublicMerchantRepositoryImpl(this._remote);

  final PublicMerchantRemoteDataSource _remote;

  @override
  Future<MerchantPortal?> portal(String token) => _remote.portal(token);

  @override
  Future<MerchantValidationResult> validate({
    required String token,
    required String pin,
    required String plate,
  }) => _remote.validate(token: token, pin: pin, plate: plate);
}
