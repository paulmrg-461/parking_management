import 'package:equatable/equatable.dart';

/// Holds created in a report window, split by origin and outcome
/// (`rpc/report_reservations`). Answers "did the public page bring cars in?".
class ReservationReport extends Equatable {
  const ReservationReport({
    this.total = 0,
    this.public = 0,
    this.app = 0,
    this.used = 0,
    this.usedPublic = 0,
    this.cancelled = 0,
    this.expired = 0,
    this.active = 0,
    this.waitlist = WaitlistReport.empty,
  });

  final int total;
  final int public;
  final int app;
  final int used;
  final int usedPublic;
  final int cancelled;
  final int expired;
  final int active;

  /// The queue behind those holds.
  final WaitlistReport waitlist;

  static const empty = ReservationReport();

  bool get hasData => total > 0;

  /// Share of the web holds that turned into a stay (`0..100`), or null when
  /// there were none.
  int? get publicConversion =>
      public == 0 ? null : (usedPublic * 100 / public).round();

  factory ReservationReport.fromJson(Map<String, dynamic> json) {
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    return ReservationReport(
      total: value(json['total']),
      public: value(json['public']),
      app: value(json['app']),
      used: value(json['used']),
      usedPublic: value(json['used_public']),
      cancelled: value(json['cancelled']),
      expired: value(json['expired']),
      active: value(json['active']),
      waitlist: json['waitlist'] is Map
          ? WaitlistReport.fromJson(
              Map<String, dynamic>.from(json['waitlist'] as Map),
            )
          : WaitlistReport.empty,
    );
  }

  @override
  List<Object?> get props => [
    total,
    public,
    app,
    used,
    usedPublic,
    cancelled,
    expired,
    active,
    waitlist,
  ];
}

/// Turns of the booking waitlist in the same window.
class WaitlistReport extends Equatable {
  const WaitlistReport({
    this.joined = 0,
    this.offered = 0,
    this.claimed = 0,
    this.expired = 0,
    this.left = 0,
    this.cancelled = 0,
    this.waiting = 0,
  });

  final int joined;
  final int offered;
  final int claimed;
  final int expired;
  final int left;
  final int cancelled;
  final int waiting;

  static const empty = WaitlistReport();

  bool get hasData => joined > 0 || waiting > 0;

  /// Share of the offers that were claimed (`0..100`), or null without offers.
  int? get conversion => offered == 0 ? null : (claimed * 100 / offered).round();

  factory WaitlistReport.fromJson(Map<String, dynamic> json) {
    int value(Object? raw) => (raw as num?)?.toInt() ?? 0;
    return WaitlistReport(
      joined: value(json['joined']),
      offered: value(json['offered']),
      claimed: value(json['claimed']),
      expired: value(json['expired']),
      left: value(json['left']),
      cancelled: value(json['cancelled']),
      waiting: value(json['waiting']),
    );
  }

  @override
  List<Object?> get props => [
    joined,
    offered,
    claimed,
    expired,
    left,
    cancelled,
    waiting,
  ];
}
