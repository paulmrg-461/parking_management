import 'package:equatable/equatable.dart';

enum FiscalDocType {
  pos,
  invoice,
  creditNote;

  String get wire => switch (this) {
    FiscalDocType.pos => 'pos',
    FiscalDocType.invoice => 'invoice',
    FiscalDocType.creditNote => 'credit_note',
  };

  static FiscalDocType parse(String? value) => switch (value) {
    'invoice' => FiscalDocType.invoice,
    'credit_note' => FiscalDocType.creditNote,
    _ => FiscalDocType.pos,
  };
}

/// Authorized numbering range. Saving one deactivates the previous active
/// resolution of the same type.
class FiscalResolution extends Equatable {
  const FiscalResolution({
    this.id,
    required this.docType,
    required this.resolutionNumber,
    this.prefix = '',
    required this.rangeFrom,
    required this.rangeTo,
    this.nextNumber,
    required this.validFrom,
    required this.validTo,
    this.active = true,
    this.remaining = 0,
  });

  final int? id;
  final FiscalDocType docType;
  final String resolutionNumber;
  final String prefix;
  final int rangeFrom;
  final int rangeTo;
  final int? nextNumber;
  final DateTime validFrom;
  final DateTime validTo;
  final bool active;
  final int remaining;

  factory FiscalResolution.fromJson(Map<String, dynamic> json) =>
      FiscalResolution(
        id: (json['id'] as num?)?.toInt(),
        docType: FiscalDocType.parse(json['doc_type'] as String?),
        resolutionNumber: json['resolution_number'] as String? ?? '',
        prefix: json['prefix'] as String? ?? '',
        rangeFrom: (json['range_from'] as num?)?.toInt() ?? 1,
        rangeTo: (json['range_to'] as num?)?.toInt() ?? 1,
        nextNumber: (json['next_number'] as num?)?.toInt(),
        validFrom: DateTime.tryParse(json['valid_from'] as String? ?? '') ??
            DateTime(1970),
        validTo: DateTime.tryParse(json['valid_to'] as String? ?? '') ??
            DateTime(1970),
        active: json['active'] as bool? ?? true,
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'doc_type': docType.wire,
    'resolution_number': resolutionNumber,
    'prefix': prefix,
    'range_from': rangeFrom,
    'range_to': rangeTo,
    'valid_from': _date(validFrom),
    'valid_to': _date(validTo),
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [
    id,
    docType,
    resolutionNumber,
    prefix,
    rangeFrom,
    rangeTo,
    nextNumber,
    validFrom,
    validTo,
    active,
    remaining,
  ];
}
