import 'package:equatable/equatable.dart';

/// One entry in the site's activity log (a parking session, open or closed).
class SessionRecord extends Equatable {
  const SessionRecord({
    required this.id,
    required this.plate,
    required this.category,
    required this.entryTime,
    required this.status,
    this.exitTime,
    this.amountCharged = 0,
    this.ticketNumber,
    this.paymentMethod,
    this.durationSeconds = 0,
  });

  final int id;
  final String plate;
  final String category;
  final DateTime entryTime;
  final DateTime? exitTime;
  final String status;
  final int amountCharged;
  final String? ticketNumber;
  final String? paymentMethod;
  final int durationSeconds;

  bool get isOpen => status == 'open';

  Duration get duration => Duration(seconds: durationSeconds);

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    id: (json['id'] as num).toInt(),
    plate: json['plate'] as String,
    category: json['category'] as String? ?? '',
    entryTime: DateTime.parse(json['entry_time'] as String),
    exitTime: json['exit_time'] == null
        ? null
        : DateTime.parse(json['exit_time'] as String),
    status: json['status'] as String? ?? 'open',
    amountCharged: (json['amount_charged'] as num?)?.toInt() ?? 0,
    ticketNumber: json['ticket_number'] as String?,
    paymentMethod: json['payment_method'] as String?,
    durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [
    id,
    plate,
    category,
    entryTime,
    exitTime,
    status,
    amountCharged,
    ticketNumber,
    paymentMethod,
    durationSeconds,
  ];
}

/// One page of the log plus the total rows the filter matches.
class SessionRecordPage {
  const SessionRecordPage({required this.items, required this.total});

  final List<SessionRecord> items;
  final int total;
}
