import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/online_payments/domain/entities/payment_intent.dart';
import 'package:parking_management/features/online_payments/domain/entities/payment_status.dart';
import 'package:parking_management/features/online_payments/domain/repositories/online_payment_repository.dart';

/// In-memory port fake for the pay-online cubit and page tests.
class FakeOnlinePaymentRepository implements OnlinePaymentRepository {
  FakeOnlinePaymentRepository({
    this.intent,
    this.failure,
    this.statuses = const [],
  });

  PaymentIntent? intent;
  Failure? failure;
  List<PaymentIntentStatus> statuses;
  int intentCalls = 0;
  int statusCalls = 0;
  String? lastReference;
  String? lastPlate;

  @override
  Future<PaymentIntent> createIntent({
    required int sessionId,
    required String plate,
  }) async {
    intentCalls++;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return intent ??
        PaymentIntent(
          intentId: 9,
          reference: 'PM-1A2B3C4D5E6F',
          amount: 6000,
          currency: 'COP',
          checkoutUrl: 'https://checkout.test/p/?reference=PM-1A2B3C4D5E6F',
          expiresAt: DateTime(2026, 11, 17, 12, 30),
        );
  }

  @override
  Future<PaymentIntentStatus?> status({
    required String reference,
    required String plate,
  }) async {
    statusCalls++;
    lastReference = reference;
    lastPlate = plate;
    if (statuses.isEmpty) {
      return null;
    }
    return statuses.length == 1 ? statuses.first : statuses.removeAt(0);
  }
}
