import '../entities/merchant_portal.dart';
import '../entities/merchant_validation_result.dart';

/// Anonymous port for `/validate?m=`: the token is the access key.
abstract class PublicMerchantRepository {
  /// `null` when the token matches no active merchant.
  Future<MerchantPortal?> portal(String token);

  Future<MerchantValidationResult> validate({
    required String token,
    required String pin,
    required String plate,
  });
}
