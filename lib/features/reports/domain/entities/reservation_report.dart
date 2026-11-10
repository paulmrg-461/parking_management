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
  });

  final int total;
  final int public;
  final int app;
  final int used;
  final int usedPublic;
  final int cancelled;
  final int expired;
  final int active;

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
  ];
}
