import 'package:equatable/equatable.dart';

enum MerchantBenefitKind { freeMinutes, percentage, fixedAmount }

extension MerchantBenefitKindX on MerchantBenefitKind {
  String get wire => switch (this) {
    MerchantBenefitKind.freeMinutes => 'free_minutes',
    MerchantBenefitKind.percentage => 'percentage',
    MerchantBenefitKind.fixedAmount => 'fixed_amount',
  };

  static MerchantBenefitKind parse(String? value) => switch (value) {
    'free_minutes' => MerchantBenefitKind.freeMinutes,
    'fixed_amount' => MerchantBenefitKind.fixedAmount,
    _ => MerchantBenefitKind.percentage,
  };
}

enum MerchantBillingMode { merchantPaid, courtesy }

extension MerchantBillingModeX on MerchantBillingMode {
  String get wire => switch (this) {
    MerchantBillingMode.merchantPaid => 'merchant_paid',
    MerchantBillingMode.courtesy => 'courtesy',
  };

  static MerchantBillingMode parse(String? value) =>
      value == 'courtesy'
      ? MerchantBillingMode.courtesy
      : MerchantBillingMode.merchantPaid;
}

/// One agreement of the active lot, with the usage counters the admin needs.
class Merchant extends Equatable {
  const Merchant({
    required this.id,
    required this.name,
    required this.kind,
    required this.value,
    required this.billingMode,
    this.maxAmount,
    this.dailyCap,
    this.monthlyCap,
    this.active = true,
    this.usedToday = 0,
    this.usedMonth = 0,
    this.pendingNow = 0,
    this.locked = false,
    this.credentialsVersion = 1,
  });

  final int id;
  final String name;
  final MerchantBenefitKind kind;
  final int value;
  final int? maxAmount;
  final MerchantBillingMode billingMode;
  final int? dailyCap;
  final int? monthlyCap;
  final bool active;
  final int usedToday;
  final int usedMonth;
  final int pendingNow;
  final bool locked;
  final int credentialsVersion;

  factory Merchant.fromJson(Map<String, dynamic> json) => Merchant(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    kind: MerchantBenefitKindX.parse(json['benefit_kind'] as String?),
    value: (json['benefit_value'] as num?)?.toInt() ?? 0,
    maxAmount: (json['max_amount'] as num?)?.toInt(),
    billingMode: MerchantBillingModeX.parse(json['billing_mode'] as String?),
    dailyCap: (json['daily_cap'] as num?)?.toInt(),
    monthlyCap: (json['monthly_cap'] as num?)?.toInt(),
    active: json['active'] as bool? ?? true,
    usedToday: (json['used_today'] as num?)?.toInt() ?? 0,
    usedMonth: (json['used_month'] as num?)?.toInt() ?? 0,
    pendingNow: (json['pending_now'] as num?)?.toInt() ?? 0,
    locked: json['locked'] as bool? ?? false,
    credentialsVersion: (json['credentials_version'] as num?)?.toInt() ?? 1,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    value,
    maxAmount,
    billingMode,
    dailyCap,
    monthlyCap,
    active,
    usedToday,
    usedMonth,
    pendingNow,
    locked,
    credentialsVersion,
  ];
}

/// Editable fields of a merchant (full replacement, see `save_merchant`).
class MerchantDraft extends Equatable {
  const MerchantDraft({
    this.id,
    required this.name,
    required this.kind,
    required this.value,
    this.maxAmount,
    this.billingMode = MerchantBillingMode.merchantPaid,
    this.dailyCap,
    this.monthlyCap,
    this.active = true,
  });

  final int? id;
  final String name;
  final MerchantBenefitKind kind;
  final int value;
  final int? maxAmount;
  final MerchantBillingMode billingMode;
  final int? dailyCap;
  final int? monthlyCap;
  final bool active;

  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    value,
    maxAmount,
    billingMode,
    dailyCap,
    monthlyCap,
    active,
  ];
}

/// Show-once credentials of a merchant.
class MerchantCredentials extends Equatable {
  const MerchantCredentials({
    required this.merchantId,
    required this.pin,
    this.token,
    this.linkPath,
  });

  final int merchantId;
  final String pin;

  /// Only present on creation and token rotation (the old token is lost).
  final String? token;
  final String? linkPath;

  /// Absolute link when the app base URL is configured.
  Uri? linkFor(Uri? appBase) {
    final path = linkPath;
    if (path == null || path.isEmpty || appBase == null) {
      return null;
    }
    final parts = Uri.parse(path);
    return appBase.replace(path: parts.path, query: parts.query);
  }

  @override
  List<Object?> get props => [merchantId, pin, token, linkPath];
}
