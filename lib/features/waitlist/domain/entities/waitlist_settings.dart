import 'package:equatable/equatable.dart';

/// The three per-lot switches the admin edits from the reservations board.
class WaitlistSettings extends Equatable {
  const WaitlistSettings({
    required this.enabled,
    required this.claimMinutes,
    required this.maxEntries,
  });

  final bool enabled;
  final int claimMinutes;
  final int maxEntries;

  static const defaults = WaitlistSettings(
    enabled: false,
    claimMinutes: 15,
    maxEntries: 30,
  );

  factory WaitlistSettings.fromJson(Map<String, dynamic> json) =>
      WaitlistSettings(
        enabled: json['enabled'] == true ||
            json['waitlist_enabled'] == true,
        claimMinutes:
            (json['claim_minutes'] as num?)?.toInt() ??
            (json['waitlist_claim_minutes'] as num?)?.toInt() ??
            15,
        maxEntries:
            (json['max_entries'] as num?)?.toInt() ??
            (json['waitlist_max_entries'] as num?)?.toInt() ??
            30,
      );

  WaitlistSettings copyWith({
    bool? enabled,
    int? claimMinutes,
    int? maxEntries,
  }) => WaitlistSettings(
    enabled: enabled ?? this.enabled,
    claimMinutes: claimMinutes ?? this.claimMinutes,
    maxEntries: maxEntries ?? this.maxEntries,
  );

  @override
  List<Object?> get props => [enabled, claimMinutes, maxEntries];
}
