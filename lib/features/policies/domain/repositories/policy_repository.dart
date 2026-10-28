import '../entities/lot_profile.dart';

/// Public site profile + legal policy (anon read).
abstract class PolicyRepository {
  Future<LotProfile> fetch(int lotId);
}
