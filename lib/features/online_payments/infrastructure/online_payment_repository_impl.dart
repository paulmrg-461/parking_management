import '../domain/entities/payment_intent.dart';
import '../domain/entities/payment_status.dart';
import '../domain/repositories/online_payment_repository.dart';
import 'online_payment_remote_data_source.dart';

class OnlinePaymentRepositoryImpl implements OnlinePaymentRepository {
  OnlinePaymentRepositoryImpl(this._remote);

  final OnlinePaymentRemoteDataSource _remote;

  @override
  Future<PaymentIntent> createIntent({
    required int sessionId,
    required String plate,
  }) => _remote.createIntent(sessionId: sessionId, plate: plate);

  @override
  Future<PaymentIntentStatus?> status({
    required String reference,
    required String plate,
  }) => _remote.status(reference: reference, plate: plate);
}
