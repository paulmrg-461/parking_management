import 'package:equatable/equatable.dart';

import 'fiscal_customer.dart';
import 'fiscal_resolution.dart';

enum FiscalStatus {
  pending,
  sent,
  accepted,
  rejected,
  failed;

  String get wire => name;

  static FiscalStatus parse(String? value) => switch (value) {
    'sent' => FiscalStatus.sent,
    'accepted' => FiscalStatus.accepted,
    'rejected' => FiscalStatus.rejected,
    'failed' => FiscalStatus.failed,
    _ => FiscalStatus.pending,
  };

  bool get canRetry => this == FiscalStatus.rejected || this == FiscalStatus.failed;
  bool get isAccepted => this == FiscalStatus.accepted;
}

/// The summary returned by issuance/retry/credit note and the session read.
class FiscalDocSummary extends Equatable {
  const FiscalDocSummary({
    required this.documentId,
    required this.docType,
    required this.fullNumber,
    required this.status,
    this.total = 0,
    this.taxAmount = 0,
    this.issuedAt,
    this.cufe,
    this.qrData,
  });

  final int documentId;
  final FiscalDocType docType;
  final String fullNumber;
  final FiscalStatus status;
  final int total;
  final int taxAmount;
  final DateTime? issuedAt;
  final String? cufe;
  final String? qrData;

  factory FiscalDocSummary.fromJson(Map<String, dynamic> json) =>
      FiscalDocSummary(
        documentId:
            (json['document_id'] as num?)?.toInt() ??
            (json['id'] as num?)?.toInt() ??
            0,
        docType: FiscalDocType.parse(json['doc_type'] as String?),
        fullNumber: json['full_number'] as String? ?? '',
        status: FiscalStatus.parse(json['status'] as String?),
        total: (json['total'] as num?)?.toInt() ?? 0,
        taxAmount: (json['tax_amount'] as num?)?.toInt() ?? 0,
        issuedAt: DateTime.tryParse(json['issued_at'] as String? ?? ''),
        cufe: json['cufe'] as String?,
        qrData: json['qr_data'] as String?,
      );

  @override
  List<Object?> get props => [
    documentId,
    docType,
    fullNumber,
    status,
    total,
    taxAmount,
    issuedAt,
    cufe,
    qrData,
  ];
}

/// One row of the admin document list (customer PII is admin-only).
class FiscalDocument extends Equatable {
  const FiscalDocument({
    required this.id,
    required this.docType,
    required this.fullNumber,
    required this.status,
    this.total = 0,
    this.taxAmount = 0,
    this.issuedAt,
    this.sourceKind,
    this.sourceId,
    this.customerName,
    this.customerDocType,
    this.customerDocNumber,
    this.cufe,
    this.rejectionReason,
    this.lastError,
    this.attempts = 0,
    this.voided = false,
  });

  final int id;
  final FiscalDocType docType;
  final String fullNumber;
  final FiscalStatus status;
  final int total;
  final int taxAmount;
  final DateTime? issuedAt;
  final String? sourceKind;
  final int? sourceId;
  final String? customerName;
  final FiscalIdType? customerDocType;
  final String? customerDocNumber;
  final String? cufe;
  final String? rejectionReason;
  final String? lastError;
  final int attempts;
  final bool voided;

  factory FiscalDocument.fromJson(Map<String, dynamic> json) => FiscalDocument(
    id: (json['id'] as num?)?.toInt() ?? 0,
    docType: FiscalDocType.parse(json['doc_type'] as String?),
    fullNumber: json['full_number'] as String? ?? '',
    status: FiscalStatus.parse(json['status'] as String?),
    total: (json['total'] as num?)?.toInt() ?? 0,
    taxAmount: (json['tax_amount'] as num?)?.toInt() ?? 0,
    issuedAt: DateTime.tryParse(json['issued_at'] as String? ?? ''),
    sourceKind: json['source_kind'] as String?,
    sourceId: (json['source_id'] as num?)?.toInt(),
    customerName: json['customer_name'] as String?,
    customerDocType: json['customer_doc_type'] is String
        ? FiscalIdType.parse(json['customer_doc_type'] as String)
        : null,
    customerDocNumber: json['customer_doc_number'] as String?,
    cufe: json['cufe'] as String?,
    rejectionReason: json['rejection_reason'] as String?,
    lastError: json['last_error'] as String?,
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    voided: json['voided_at'] != null,
  );

  @override
  List<Object?> get props => [
    id,
    docType,
    fullNumber,
    status,
    total,
    taxAmount,
    issuedAt,
    sourceKind,
    sourceId,
    customerName,
    customerDocType,
    customerDocNumber,
    cufe,
    rejectionReason,
    lastError,
    attempts,
    voided,
  ];
}
