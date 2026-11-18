import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/fare/fare_quote.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant_settlement.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant_validation_result.dart';
import 'package:parking_management/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:parking_management/features/merchants/domain/repositories/public_merchant_repository.dart';
import 'package:parking_management/features/merchants/domain/entities/merchant_portal.dart';

final sampleMerchant = Merchant(
  id: 1,
  name: 'Cafe Uno',
  kind: MerchantBenefitKind.percentage,
  value: 10,
  billingMode: MerchantBillingMode.merchantPaid,
);

class FakeMerchantRepository implements MerchantRepository {
  FakeMerchantRepository({List<Merchant>? merchants, this.policy = 1})
    : merchants = merchants ?? [sampleMerchant];

  List<Merchant> merchants;
  int policy;
  Failure? listError;
  Failure? writeError;
  Failure? listActiveError;
  MerchantCredentials? credentialsToReturn;
  final List<MerchantDraft> saved = [];
  final List<int> deleted = [];
  final List<int> resetIds = [];
  final List<int> applied = [];
  final List<({int id, String reason})> revoked = [];
  int policySaves = 0;

  @override
  Future<List<Merchant>> list() async {
    final error = listError;
    if (error != null) {
      throw error;
    }
    return List.of(merchants);
  }

  @override
  Future<List<Merchant>> listActive() async {
    final error = listActiveError;
    if (error != null) {
      throw error;
    }
    return merchants.where((m) => m.active).toList();
  }

  @override
  Future<({Merchant merchant, MerchantCredentials? credentials})> save(
    MerchantDraft draft,
  ) async {
    _throwIfWriteFails();
    saved.add(draft);
    final merchant = Merchant(
      id: draft.id ?? 9,
      name: draft.name,
      kind: draft.kind,
      value: draft.value,
      maxAmount: draft.maxAmount,
      billingMode: draft.billingMode,
      dailyCap: draft.dailyCap,
      monthlyCap: draft.monthlyCap,
      active: draft.active,
    );
    merchants = [
      for (final item in merchants)
        if (item.id != merchant.id) item,
      merchant,
    ];
    return (merchant: merchant, credentials: credentialsToReturn);
  }

  @override
  Future<MerchantCredentials> resetCredentials(
    int merchantId, {
    bool rotateToken = false,
  }) async {
    _throwIfWriteFails();
    resetIds.add(merchantId);
    return MerchantCredentials(
      merchantId: merchantId,
      pin: '123456',
      token: rotateToken ? 'a' * 48 : null,
      linkPath: rotateToken ? '/validate?m=${'a' * 48}' : null,
    );
  }

  @override
  Future<void> delete(int merchantId) async {
    _throwIfWriteFails();
    deleted.add(merchantId);
    merchants = [
      for (final item in merchants)
        if (item.id != merchantId) item,
    ];
  }

  @override
  Future<int> loadPolicy() async => policy;

  @override
  Future<int> savePolicy(int maxPerSession) async {
    _throwIfWriteFails();
    policySaves++;
    policy = maxPerSession;
    return maxPerSession;
  }

  @override
  Future<FareQuote> addValidation({
    required int merchantId,
    required int sessionId,
  }) async {
    applied.add(merchantId);
    return const FareQuote(
      sessionId: 1,
      baseAmount: 9000,
      gross: 9000,
      amountDue: 4500,
    );
  }

  @override
  Future<void> revokeValidation({
    required int validationId,
    required String reason,
  }) async {
    revoked.add((id: validationId, reason: reason));
  }

  @override
  Future<MerchantSettlement> settlement({
    required DateTime start,
    required DateTime end,
  }) async {
    final error = listError;
    if (error != null) {
      throw error;
    }
    return MerchantSettlement(from: start, to: end);
  }

  void _throwIfWriteFails() {
    final error = writeError;
    if (error != null) {
      throw error;
    }
  }
}

class FakePublicMerchantRepository implements PublicMerchantRepository {
  FakePublicMerchantRepository({
    this.portalResult,
    this.result,
    this.portalError,
    this.error,
  });

  MerchantPortal? portalResult;
  MerchantValidationResult? result;
  Failure? portalError;
  Failure? error;
  final List<({String token, String pin, String plate})> calls = [];
  int portalCalls = 0;
  Future<void>? portalGate;

  @override
  Future<MerchantPortal?> portal(String token) async {
    portalCalls++;
    await portalGate;
    final failure = portalError;
    if (failure != null) {
      throw failure;
    }
    return portalResult;
  }

  @override
  Future<MerchantValidationResult> validate({
    required String token,
    required String pin,
    required String plate,
  }) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    calls.add((token: token, pin: pin, plate: plate));
    return result ??
        ValidationRegistered(
          const MerchantPortal(
            merchantName: 'Cafe Uno',
            kind: MerchantBenefitKind.percentage,
            value: 10,
            lotName: 'Central',
          ),
        );
  }
}

const samplePortal = MerchantPortal(
  merchantName: 'Cafe Uno',
  kind: MerchantBenefitKind.percentage,
  value: 10,
  lotName: 'Central',
);
