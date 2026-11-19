import '../domain/entities/pass_renewal_checkout.dart';
import '../domain/entities/pass_renewal_offer.dart';
import '../domain/repositories/pass_renewal_repository.dart';
import 'pass_renewal_remote_data_source.dart';

class PassRenewalRepositoryImpl implements PassRenewalRepository {
  PassRenewalRepositoryImpl(this._remote);

  final PassRenewalRemoteDataSource _remote;

  @override
  Future<PassRenewalOffer?> load(String token) => _remote.load(token);

  @override
  Future<PassRenewalCheckout> startPayment(String token) =>
      _remote.startPayment(token);
}
