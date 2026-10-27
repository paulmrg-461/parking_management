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

  /// `true` when the pass is expired or ends within [days] calendar days, so
  /// the list can offer a manual renewal.
  bool needsRenewal({DateTime? now, int days = 7}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !end.isAfter(today.add(Duration(days: days)));
  }

  /// Period a manual renewal covers: the day after the current end (or today
  /// when it already expired), 30 days inclusive.
  ({DateTime start, DateTime end}) renewedPeriod({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final start = end.isBefore(today) ? today : end.add(const Duration(days: 1));
    return (start: start, end: start.add(const Duration(days: 29)));
  }

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
