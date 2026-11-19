import '../entities/loyalty_account.dart';
import '../entities/loyalty_report.dart';
import '../entities/loyalty_settings.dart';
import '../entities/loyalty_status.dart';

/// The operator's redemption choice, stored before check-out.
enum LoyaltyChoice {
  redeem,
  skip,
  auto;

  String get wire => name;
}

/// Result of a manual progress correction.
class LoyaltyAdjustResult {
  const LoyaltyAdjustResult({
    required this.plate,
    required this.progress,
    required this.required,
    required this.delta,
  });

  final String plate;
  final int progress;
  final int required;
  final int delta;

  factory LoyaltyAdjustResult.fromJson(Map<String, dynamic> json) =>
      LoyaltyAdjustResult(
        plate: json['plate'] as String? ?? '',
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        required: (json['required'] as num?)?.toInt() ?? 0,
        delta: (json['delta'] as num?)?.toInt() ?? 0,
      );
}

/// Loyalty port. Online only: nothing here is queued in the outbox.
abstract class LoyaltyRepository {
  Future<LoyaltyStatus> status(String plate);

  Future<LoyaltySettings> loadSettings();

  Future<LoyaltySettings> saveSettings(LoyaltySettings settings);

  Future<void> choose({
    required int sessionId,
    required LoyaltyChoice choice,
  });

  Future<List<LoyaltyAccount>> accounts({String? search});

  Future<LoyaltyAdjustResult> adjust({
    required String plate,
    required int delta,
    required String reason,
  });

  Future<LoyaltyReport> report({
    required DateTime start,
    required DateTime end,
  });
}
