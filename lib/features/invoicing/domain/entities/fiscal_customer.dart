import 'package:equatable/equatable.dart';

/// Customer document types accepted by the fiscal provider.
enum FiscalIdType {
  cc,
  nit,
  ce,
  pp,
  ti,
  rc,
  te,
  die;

  String get wire => name.toUpperCase();

  static FiscalIdType parse(String? value) => FiscalIdType.values.firstWhere(
    (type) => type.wire == (value ?? '').toUpperCase(),
    orElse: () => FiscalIdType.cc,
  );
}

/// Optional buyer data. `null` on the checkout choice means a final-consumer
/// POS document; a non-null customer produces an invoice.
class FiscalCustomer extends Equatable {
  const FiscalCustomer({
    required this.documentType,
    required this.documentNumber,
    required this.name,
    this.email,
  });

  final FiscalIdType documentType;
  final String documentNumber;
  final String name;
  final String? email;

  static final _numberPattern = RegExp(r'^[A-Za-z0-9]{3,20}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Trimmed, upper-case document number and trimmed name/email.
  FiscalCustomer normalized() => FiscalCustomer(
    documentType: documentType,
    documentNumber: documentNumber.replaceAll(RegExp(r'\s'), '').toUpperCase(),
    name: name.trim(),
    email: email?.trim().isEmpty ?? true ? null : email!.trim(),
  );

  bool get isValid {
    final value = normalized();
    return _numberPattern.hasMatch(value.documentNumber) &&
        value.name.length >= 2 &&
        value.name.length <= 120 &&
        (value.email == null ||
            (value.email!.length <= 120 &&
                _emailPattern.hasMatch(value.email!)));
  }

  Map<String, dynamic> toJson() {
    final value = normalized();
    return {
      'document_type': value.documentType.wire,
      'document_number': value.documentNumber,
      'name': value.name,
      'email': value.email,
    };
  }

  factory FiscalCustomer.fromJson(Map<String, dynamic> json) => FiscalCustomer(
    documentType: FiscalIdType.parse(json['document_type'] as String?),
    documentNumber: json['document_number'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String?,
  );

  @override
  List<Object?> get props => [documentType, documentNumber, name, email];
}
