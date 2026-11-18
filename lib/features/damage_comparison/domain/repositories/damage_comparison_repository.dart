import '../entities/damage_comparison.dart';

abstract class DamageComparisonRepository {
  Future<DamageAiStatus> status();

  Future<DamageView> load(int sessionId, {int? run});

  Future<DamageView> run({
    required int sessionId,
    String locale = 'es',
  });

  Future<DamageFinding> review({
    required int findingId,
    required FindingReview status,
    required String note,
  });
}
