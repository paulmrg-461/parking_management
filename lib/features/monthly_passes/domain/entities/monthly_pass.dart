import 'package:equatable/equatable.dart';

class MonthlyPass extends Equatable {
  const MonthlyPass({
    this.id,
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    required this.amount,
    this.active = true,
    this.autoRenew = false,
    this.autoRenewPaymentMethod = 'cash',
  });

  final int? id;
  final int vehicleId;
  final DateTime startDate;
  final DateTime endDate;
  final int amount;
  final bool active;
  final bool autoRenew;
  final String autoRenewPaymentMethod;

  @override
  List<Object?> get props =>
      [
        id,
        vehicleId,
        startDate,
        endDate,
        amount,
        active,
        autoRenew,
        autoRenewPaymentMethod,
      ];
}

enum MonthlyPassStatus { active, upcoming, expired }

/// `active` covers today; `upcoming` starts in the future; `expired` ended
/// before today. Dates are compared by calendar day in local time.
MonthlyPassStatus monthlyPassStatus(MonthlyPass pass, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(
    pass.startDate.year,
    pass.startDate.month,
    pass.startDate.day,
  );
  final end = DateTime(pass.endDate.year, pass.endDate.month, pass.endDate.day);
  if (end.isBefore(today)) {
    return MonthlyPassStatus.expired;
  }
  return start.isAfter(today)
      ? MonthlyPassStatus.upcoming
      : MonthlyPassStatus.active;
}

/// Active passes first (soonest expiry first), then upcoming (soonest start),
/// then expired (most recent first). Stable for equal keys.
List<MonthlyPass> sortMonthlyPasses(
  List<MonthlyPass> passes, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  int priority(MonthlyPass pass) => switch (monthlyPassStatus(pass, today)) {
    MonthlyPassStatus.active => 0,
    MonthlyPassStatus.upcoming => 1,
    MonthlyPassStatus.expired => 2,
  };
  final sorted = [...passes];
  sorted.sort((a, b) {
    final byPriority = priority(a).compareTo(priority(b));
    if (byPriority != 0) {
      return byPriority;
    }
    final aExpired = priority(a) == 2;
    return aExpired
        ? b.endDate.compareTo(a.endDate)
        : a.endDate.compareTo(b.endDate);
  });
  return sorted;
}
