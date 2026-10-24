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
    this.lostTicket = false,
    this.lotId,
    this.lotName,
    this.discountAmount = 0,
    this.discountReason,
  });

  final int id;
  final DateTime entryTime;
  final DateTime? exitTime;
  final String status;
  final int? amountCharged;
  final String? ticketNumber;
  final String? paymentMethod;
  final int durationSeconds;
  final bool lostTicket;
  final int? lotId;
  final String? lotName;
  final int discountAmount;
  final String? discountReason;

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
        lostTicket: json['lost_ticket'] == true,
        lotId: (json['lot_id'] as num?)?.toInt(),
        lotName: json['lot_name'] as String?,
        discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
        discountReason: json['discount_reason'] as String?,
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
    'lost_ticket': lostTicket,
    'lot_id': lotId,
    'lot_name': lotName,
    'discount_amount': discountAmount,
    'discount_reason': discountReason,
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
    lostTicket,
    lotId,
    lotName,
    discountAmount,
    discountReason,
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
    this.isBlacklisted = false,
    this.notes,
    this.currentLotVisits = 0,
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
  final bool isBlacklisted;
  final String? notes;

  /// Visits at the lot the app is currently working in.
  final int currentLotVisits;

  /// Distinct sites the plate has visited, for the history filter.
  List<({int id, String name})> get lots {
    final seen = <int, String>{};
    for (final session in sessions) {
      final id = session.lotId;
      if (id != null) {
        seen.putIfAbsent(id, () => session.lotName ?? '#$id');
      }
    }
    final entries = [
      for (final entry in seen.entries) (id: entry.key, name: entry.value),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return entries;
  }

  VehicleHistory withFlags({
    bool? isBlacklisted,
    String? notes,
    bool replaceNotes = false,
  }) =>
      VehicleHistory(
        plate: plate,
        vehicleId: vehicleId,
        categoryName: categoryName,
        color: color,
        brand: brand,
        visits: visits,
        totalSpent: totalSpent,
        openSessions: openSessions,
        sessions: sessions,
        isBlacklisted: isBlacklisted ?? this.isBlacklisted,
        notes: replaceNotes ? notes : (notes ?? this.notes),
        currentLotVisits: currentLotVisits,
      );

  factory VehicleHistory.fromJson(Map<String, dynamic> json) => VehicleHistory(
    plate: json['plate'] as String,
    vehicleId: (json['vehicle_id'] as num).toInt(),
    categoryName: json['category_name'] as String? ?? '',
    color: json['color'] as String?,
    brand: json['brand'] as String?,
    isBlacklisted: json['is_blacklisted'] == true,
    notes: json['notes'] as String?,
    currentLotVisits: (json['current_lot_visits'] as num?)?.toInt() ?? 0,
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
    'is_blacklisted': isBlacklisted,
    'notes': notes,
    'current_lot_visits': currentLotVisits,
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
    isBlacklisted,
    notes,
    currentLotVisits,
  ];
}
