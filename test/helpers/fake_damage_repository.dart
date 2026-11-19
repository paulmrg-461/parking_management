import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/damage_comparison/domain/entities/damage_comparison.dart';
import 'package:parking_management/features/damage_comparison/domain/repositories/damage_comparison_repository.dart';

class FakeDamageRepository implements DamageComparisonRepository {
  FakeDamageRepository({
    this.ai = const DamageAiStatus(configured: true, remainingRequests: 59),
    DamageView? view,
  }) : view = view ?? const DamageView(sessionId: 1);

  DamageAiStatus ai;
  DamageView view;
  Failure? loadError;
  Failure? runError;
  Failure? reviewError;
  int runCalls = 0;
  int reviewCalls = 0;
  String? lastNote;

  @override
  Future<DamageAiStatus> status() async {
    final error = loadError;
    if (error != null) throw error;
    return ai;
  }

  @override
  Future<DamageView> load(int sessionId, {int? run}) async {
    final error = loadError;
    if (error != null) throw error;
    return view;
  }

  @override
  Future<DamageView> run({required int sessionId, String locale = 'es'}) async {
    runCalls++;
    final error = runError;
    if (error != null) throw error;
    return view;
  }

  @override
  Future<DamageFinding> review({
    required int findingId,
    required FindingReview status,
    required String note,
  }) async {
    reviewCalls++;
    lastNote = note;
    final error = reviewError;
    if (error != null) throw error;
    return DamageFinding(id: findingId, reviewStatus: status, reviewNote: note);
  }
}

DamageView sampleDamageView({DamageOverall overall = DamageOverall.possible}) =>
    DamageView(
      sessionId: 1,
      runs: 1,
      comparison: DamageComparison(
        id: 9,
        status: DamageStatus.completed,
        overall: overall,
        summary: 'Un rayón.',
        entryPhotoCount: 2,
        exitPhotoCount: 2,
        findings: const [
          DamageFinding(
            id: 3,
            description: 'Rayón en la puerta',
            zone: DamageZone.left,
            classification: FindingClassification.newDamage,
            confidence: 'high',
          ),
        ],
      ),
    );
