import '../../../core/network/supabase_error_mapper.dart';
import '../../report_assistant/infrastructure/report_assistant_remote_data_source.dart'
    show FunctionsInvoker;
import '../domain/entities/damage_comparison.dart';
import '../domain/repositories/damage_comparison_repository.dart';

abstract class DamageComparisonRemoteDataSource {
  Future<DamageAiStatus> status();
  Future<DamageView> load(int sessionId, {int? run});
  Future<DamageView> run({required int sessionId, String locale});
  Future<DamageFinding> review({
    required int findingId,
    required FindingReview status,
    required String note,
  });
}

class SupabaseDamageComparisonRemoteDataSource
    implements DamageComparisonRemoteDataSource {
  SupabaseDamageComparisonRemoteDataSource(this._invoke, this._rpc);

  final FunctionsInvoker _invoke;
  final Future<dynamic> Function(String name, Map<String, dynamic> params) _rpc;

  @override
  Future<DamageAiStatus> status() async {
    try {
      final data = await _invoke('damage-compare', {'mode': 'status'});
      if (data is Map) {
        return DamageAiStatus.fromJson(Map<String, dynamic>.from(data));
      }
      return const DamageAiStatus();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<DamageView> load(int sessionId, {int? run}) async {
    try {
      final data = await _rpc('get_damage_comparison', {
        'p_session_id': sessionId,
        'p_run': run,
      });
      return DamageView.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<DamageView> run({
    required int sessionId,
    String locale = 'es',
  }) async {
    await _invoke('damage-compare', {
      'mode': 'run',
      'session_id': sessionId,
      'locale': locale,
    });
    return load(sessionId);
  }

  @override
  Future<DamageFinding> review({
    required int findingId,
    required FindingReview status,
    required String note,
  }) async {
    try {
      final data = await _rpc('review_damage_finding', {
        'p_finding_id': findingId,
        'p_status': status.name == 'preExisting'
            ? 'open'
            : status.name == 'confirmed'
            ? 'confirmed'
            : 'dismissed',
        'p_note': note,
      });
      final map = Map<String, dynamic>.from(data as Map);
      return DamageFinding(
        id: (map['id'] as num?)?.toInt() ?? findingId,
        reviewStatus: FindingReview.parse(map['review_status'] as String?),
        reviewNote: map['review_note'] as String?,
        reviewedAt: DateTime.tryParse(map['reviewed_at'] as String? ?? ''),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}

class DamageComparisonRepositoryImpl implements DamageComparisonRepository {
  DamageComparisonRepositoryImpl(this._remote);

  final DamageComparisonRemoteDataSource _remote;

  @override
  Future<DamageAiStatus> status() => _remote.status();

  @override
  Future<DamageView> load(int sessionId, {int? run}) =>
      _remote.load(sessionId, run: run);

  @override
  Future<DamageView> run({required int sessionId, String locale = 'es'}) =>
      _remote.run(sessionId: sessionId, locale: locale);

  @override
  Future<DamageFinding> review({
    required int findingId,
    required FindingReview status,
    required String note,
  }) => _remote.review(findingId: findingId, status: status, note: note);
}
