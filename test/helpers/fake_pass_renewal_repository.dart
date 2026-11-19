import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/pass_renewal/domain/entities/pass_renewal_checkout.dart';
import 'package:parking_management/features/pass_renewal/domain/entities/pass_renewal_offer.dart';
import 'package:parking_management/features/pass_renewal/domain/repositories/pass_renewal_repository.dart';

class FakePassRenewalRepository implements PassRenewalRepository {
  FakePassRenewalRepository({
    this.offer,
    this.failure,
    this.paymentFailure,
    this.offers = const [],
  });

  PassRenewalOffer? offer;
  Failure? failure;
  Failure? paymentFailure;

  /// Sequence returned by successive [load] calls (the first is used by the
  /// initial load, the rest by the polling).
  List<PassRenewalOffer?> offers;
  int loadCalls = 0;
  Future<void>? loadGate;
  int paymentCalls = 0;
  String? lastToken;

  @override
  Future<PassRenewalOffer?> load(String token) async {
    loadCalls++;
    lastToken = token;
    await loadGate;
    final error = failure;
    if (error != null) {
      throw error;
    }
    if (offers.isNotEmpty) {
      return offers.length == 1 ? offers.first : offers.removeAt(0);
    }
    return offer;
  }

  @override
  Future<PassRenewalCheckout> startPayment(String token) async {
    paymentCalls++;
    final error = paymentFailure;
    if (error != null) {
      throw error;
    }
    return PassRenewalCheckout(
      checkoutUrl: 'https://checkout.test/p/?reference=PM-1A2B3C4D5E6F',
      reference: 'PM-1A2B3C4D5E6F',
      expiresAt: DateTime(2026, 11, 17, 12, 30),
    );
  }
}

PassRenewalOffer sampleOffer({
  PassRenewalStatus status = PassRenewalStatus.open,
  bool paymentLinksEnabled = true,
  DateTime? renewalPeriodStart,
  DateTime? renewalPeriodEnd,
}) => PassRenewalOffer(
  status: status,
  lotName: 'Parqueadero Central',
  plateMasked: 'ABC***',
  periodStart: DateTime(2026, 12, 1),
  periodEnd: DateTime(2026, 12, 31),
  amount: 80000,
  currency: 'COP',
  expiresAt: DateTime(2026, 11, 30),
  paymentLinksEnabled: paymentLinksEnabled,
  renewalPeriodStart: renewalPeriodStart,
  renewalPeriodEnd: renewalPeriodEnd,
);
