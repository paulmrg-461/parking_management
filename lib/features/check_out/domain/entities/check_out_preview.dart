import 'package:equatable/equatable.dart';

/// Fare preview for an open session (`rpc/check_out_preview`): the same math
/// the server uses when closing, without side effects. It carries the billing
/// breakdown so the operator can explain the charge before collecting.
class CheckOutPreview extends Equatable {
  const CheckOutPreview({
    required this.sessionId,
    required this.amount,
    this.hasPass = false,
    this.elapsedSeconds = 0,
    this.dayHours = 0,
    this.nightHours = 0,
    this.days = 0,
    this.hourlyRate,
    this.nightlyRate,
    this.dailyRate,
    this.dailyCapApplied = false,
  });

  final int sessionId;
  final int amount;
  final bool hasPass;

  /// Time between entry and the preview instant, kept server-side.
  final int elapsedSeconds;

  /// Billed hours split by day and night windows (fractional hours round up).
  final int dayHours;
  final int nightHours;

  /// Days with a charge (multi-day stays bill per day).
  final int days;

  final int? hourlyRate;
  final int? nightlyRate;
  final int? dailyRate;

  /// At least one day was billed at the daily cap instead of per hour.
  final bool dailyCapApplied;

  Duration get elapsed => Duration(seconds: elapsedSeconds);

  factory CheckOutPreview.fromJson(Map<String, dynamic> json) =>
      CheckOutPreview(
        sessionId: (json['session_id'] as num).toInt(),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        hasPass: json['has_pass'] == true,
        elapsedSeconds: (json['elapsed_seconds'] as num?)?.toInt() ?? 0,
        dayHours: (json['day_hours'] as num?)?.toInt() ?? 0,
        nightHours: (json['night_hours'] as num?)?.toInt() ?? 0,
        days: (json['days'] as num?)?.toInt() ?? 0,
        hourlyRate: (json['hourly_rate'] as num?)?.toInt(),
        nightlyRate: (json['nightly_rate'] as num?)?.toInt(),
        dailyRate: (json['daily_rate'] as num?)?.toInt(),
        dailyCapApplied: json['daily_cap_applied'] == true,
      );

  @override
  List<Object?> get props => [
    sessionId,
    amount,
    hasPass,
    elapsedSeconds,
    dayHours,
    nightHours,
    days,
    hourlyRate,
    nightlyRate,
    dailyRate,
    dailyCapApplied,
  ];
}
