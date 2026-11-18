import 'package:equatable/equatable.dart';

import '../../../../core/fare/fare_quote.dart';

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
    this.lostTicketAmount,
    this.onlinePaidAmount = 0,
    this.amountDue,
    this.graceActive = false,
    this.graceUntil,
    this.quote,
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

  /// What a lost ticket would charge right now (minor units): the larger of
  /// the regular fare and the lot's lost-ticket fee / daily tariff. `null`
  /// on servers that predate `lost_ticket_amount`.
  final int? lostTicketAmount;

  /// Already paid online (minor units); `amount` includes it.
  final int onlinePaidAmount;

  /// What the desk still collects right now (`null` = unknown, treated as
  /// `amount`). Inside the grace window it is 0.
  final int? amountDue;

  /// The customer is still inside the exit window.
  final bool graceActive;
  final DateTime? graceUntil;

  /// Benefits applied right now (merchant agreements and, later, rewards).
  final FareQuote? quote;

  /// Desk balance, falling back to the full fare on old servers.
  int get deskDue => amountDue ?? amount;

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
        lostTicketAmount: (json['lost_ticket_amount'] as num?)?.toInt(),
        onlinePaidAmount: (json['online_paid_amount'] as num?)?.toInt() ?? 0,
        amountDue: (json['amount_due'] as num?)?.toInt(),
        graceActive: json['grace_active'] as bool? ?? false,
        graceUntil: DateTime.tryParse(json['grace_until'] as String? ?? ''),
        quote: json['quote'] is Map
            ? FareQuote.fromJson(
                Map<String, dynamic>.from(json['quote'] as Map),
              )
            : null,
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
    lostTicketAmount,
    onlinePaidAmount,
    amountDue,
    graceActive,
    graceUntil,
    quote,
  ];
}
