import 'package:equatable/equatable.dart';

class VehicleHistorySession extends Equatable {
  const VehicleHistorySession({
    required this.id,
    required this.entryTime,
    required this.status,
    this.exitTime,
    this.amountCharged,
    this.ticketNumber,
    this.paymentMethod,
    this.durationSeconds = 0,
  });

  final int id;
  final DateTime entryTime;
  final DateTime? exitTime;
  final String status;
  final int? amountCharged;
  final String? ticketNumber;
  final String? paymentMethod;
  final int durationSeconds;

  bool get isOpen => status == 'open';

  factory VehicleHistorySession.fromJson(Map<String, dynamic> json) =>
      VehicleHistorySession(
        id: (json['id'] as num).toInt(),
        entryTime: DateTime.parse(json['entry_time'] as String),
        exitTime: json['exit_time'] == null
            ? null
            : DateTime.parse(json['exit_time'] as String),
        status: json['status'] as String,
        amountCharged: (json['amount_charged'] as num?)?.toInt(),
        ticketNumber: json['ticket_number'] as String?,
        paymentMethod: json['payment_method'] as String?,
        durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'entry_time': entryTime.toUtc().toIso8601String(),
    'exit_time': exitTime?.toUtc().toIso8601String(),
    'status': status,
    'amount_charged': amountCharged,
    'ticket_number': ticketNumber,
    'payment_method': paymentMethod,
    'duration_seconds': durationSeconds,
  };

  @override
  List<Object?> get props => [
    id,
    entryTime,
    exitTime,
    status,
    amountCharged,
    ticketNumber,
    paymentMethod,
    durationSeconds,
  ];
}

class VehicleHistory extends Equatable {
  const VehicleHistory({
    required this.plate,
    required this.vehicleId,
    required this.categoryName,
    required this.visits,
    required this.totalSpent,
    required this.openSessions,
    required this.sessions,
    this.color,
    this.brand,
  });

  final String plate;
  final int vehicleId;
  final String categoryName;
  final String? color;
  final String? brand;
  final int visits;
  final int totalSpent;
  final int openSessions;
  final List<VehicleHistorySession> sessions;

  factory VehicleHistory.fromJson(Map<String, dynamic> json) => VehicleHistory(
    plate: json['plate'] as String,
    vehicleId: (json['vehicle_id'] as num).toInt(),
    categoryName: json['category_name'] as String? ?? '',
    color: json['color'] as String?,
    brand: json['brand'] as String?,
    visits: (json['visits'] as num).toInt(),
    totalSpent: (json['total_spent'] as num).toInt(),
    openSessions: (json['open_sessions'] as num).toInt(),
    sessions: [
      for (final item in (json['sessions'] as List<dynamic>? ?? const []))
        VehicleHistorySession.fromJson(item as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    'plate': plate,
    'vehicle_id': vehicleId,
    'category_name': categoryName,
    'color': color,
    'brand': brand,
    'visits': visits,
    'total_spent': totalSpent,
    'open_sessions': openSessions,
    'sessions': [for (final session in sessions) session.toJson()],
  };

  @override
  List<Object?> get props => [
    plate,
    vehicleId,
    categoryName,
    color,
    brand,
    visits,
    totalSpent,
    openSessions,
    sessions,
  ];
}
