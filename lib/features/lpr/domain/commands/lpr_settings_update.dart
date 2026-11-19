import 'package:equatable/equatable.dart';

import '../entities/lpr_settings.dart';

/// Only the fields the operator touched; null means "leave it as it is".
class LprSettingsUpdate extends Equatable {
  const LprSettingsUpdate({
    this.mode,
    this.minConfidence,
    this.autoConfidence,
    this.minVotes,
    this.voteWindowSeconds,
    this.cooldownSeconds,
    this.defaultCategoryId,
    this.actingUserId,
  });

  final LprMode? mode;
  final double? minConfidence;
  final double? autoConfidence;
  final int? minVotes;
  final int? voteWindowSeconds;
  final int? cooldownSeconds;
  final int? defaultCategoryId;
  final int? actingUserId;

  @override
  List<Object?> get props => [
    mode,
    minConfidence,
    autoConfidence,
    minVotes,
    voteWindowSeconds,
    cooldownSeconds,
    defaultCategoryId,
    actingUserId,
  ];
}
