import 'package:equatable/equatable.dart';

enum FiscalMode {
  off,
  onRequest,
  always;

  String get wire => switch (this) {
    FiscalMode.off => 'off',
    FiscalMode.onRequest => 'on_request',
    FiscalMode.always => 'always',
  };

  static FiscalMode parse(String? value) => switch (value) {
    'on_request' => FiscalMode.onRequest,
    'always' => FiscalMode.always,
    _ => FiscalMode.off,
  };
}

/// Issuer data and the single tax rule (prices are tax-inclusive).
class FiscalSettings extends Equatable {
  const FiscalSettings({
    this.mode = FiscalMode.off,
    this.issuerNit,
    this.issuerLegalName,
    this.taxRegime = 'responsable_iva',
    this.taxRateBps = 1900,
    this.municipalityCode,
    this.startedAt,
  });

  final FiscalMode mode;
  final String? issuerNit;
  final String? issuerLegalName;
  final String taxRegime;
  final int taxRateBps;
  final String? municipalityCode;
  final DateTime? startedAt;

  bool get isConfigured =>
      (issuerNit ?? '').isNotEmpty &&
      (issuerLegalName ?? '').isNotEmpty &&
      (municipalityCode ?? '').isNotEmpty;

  FiscalSettings copyWith({
    FiscalMode? mode,
    String? issuerNit,
    String? issuerLegalName,
    String? taxRegime,
    int? taxRateBps,
    String? municipalityCode,
  }) => FiscalSettings(
    mode: mode ?? this.mode,
    issuerNit: issuerNit ?? this.issuerNit,
    issuerLegalName: issuerLegalName ?? this.issuerLegalName,
    taxRegime: taxRegime ?? this.taxRegime,
    taxRateBps: taxRateBps ?? this.taxRateBps,
    municipalityCode: municipalityCode ?? this.municipalityCode,
    startedAt: startedAt,
  );

  factory FiscalSettings.fromJson(Map<String, dynamic> json) => FiscalSettings(
    mode: FiscalMode.parse(json['mode'] as String?),
    issuerNit: json['issuer_nit'] as String?,
    issuerLegalName: json['issuer_legal_name'] as String?,
    taxRegime: json['tax_regime'] as String? ?? 'responsable_iva',
    taxRateBps: (json['tax_rate_bps'] as num?)?.toInt() ?? 1900,
    municipalityCode: json['municipality_code'] as String?,
    startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.wire,
    'issuer_nit': issuerNit,
    'issuer_legal_name': issuerLegalName,
    'tax_regime': taxRegime,
    'tax_rate_bps': taxRateBps,
    'municipality_code': municipalityCode,
  };

  @override
  List<Object?> get props => [
    mode,
    issuerNit,
    issuerLegalName,
    taxRegime,
    taxRateBps,
    municipalityCode,
    startedAt,
  ];
}

/// What the check-out dialog needs to decide whether to show the section.
class FiscalConfig extends Equatable {
  const FiscalConfig({
    this.mode = FiscalMode.off,
    this.hasPosResolution = false,
    this.hasInvoiceResolution = false,
    this.taxRateBps = 1900,
  });

  final FiscalMode mode;
  final bool hasPosResolution;
  final bool hasInvoiceResolution;
  final int taxRateBps;

  bool get enabled => mode != FiscalMode.off;

  factory FiscalConfig.fromJson(Map<String, dynamic> json) => FiscalConfig(
    mode: FiscalMode.parse(json['mode'] as String?),
    hasPosResolution: json['has_pos_resolution'] as bool? ?? false,
    hasInvoiceResolution: json['has_invoice_resolution'] as bool? ?? false,
    taxRateBps: (json['tax_rate_bps'] as num?)?.toInt() ?? 1900,
  );

  @override
  List<Object?> get props => [mode, hasPosResolution, hasInvoiceResolution, taxRateBps];
}
