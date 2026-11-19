import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/damage_comparison/domain/entities/damage_comparison.dart';
import 'package:parking_management/features/damage_comparison/infrastructure/damage_comparison_remote_data_source.dart';

void main() {
  test('status maps configured and budget', () async {
    final remote = SupabaseDamageComparisonRemoteDataSource(
      (name, body, {headers}) async => {
        'configured': true,
        'budget': {'remaining_requests': 42},
      },
      (name, params) async => {},
    );
    final status = await remote.status();
    expect(status.configured, isTrue);
    expect(status.remainingRequests, 42);
  });

  test('load maps the RPC result', () async {
    final remote = SupabaseDamageComparisonRemoteDataSource(
      (name, body, {headers}) async => {},
      (name, params) async => {
        'session_id': 1,
        'runs': 1,
        'comparison': {
          'id': 9,
          'status': 'completed',
          'overall': 'no_new_damage',
          'findings': <Object>[],
        },
      },
    );
    final view = await remote.load(1);
    expect(view.comparison?.overall, DamageOverall.none);
  });

  test('run invokes and reloads', () async {
    final names = <String>[];
    final remote = SupabaseDamageComparisonRemoteDataSource(
      (name, body, {headers}) async {
        names.add(body['mode'] as String);
        return {'configured': true};
      },
      (name, params) async => {
        'session_id': 1,
        'runs': 1,
        'comparison': {'id': 9, 'status': 'completed', 'overall': 'no_new_damage'},
      },
    );
    await remote.run(sessionId: 1);
    expect(names, ['run']);
  });

  test('review maps the note and status', () async {
    Map<String, dynamic>? sent;
    final remote = SupabaseDamageComparisonRemoteDataSource(
      (name, body, {headers}) async => {},
      (name, params) async {
        sent = params;
        return {
          'id': 3,
          'review_status': 'confirmed',
          'review_note': 'ok',
        };
      },
    );
    final finding = await remote.review(
      findingId: 3,
      status: FindingReview.confirmed,
      note: 'Verificado',
    );
    expect(finding.reviewStatus, FindingReview.confirmed);
    expect(sent?['p_note'], 'Verificado');
  });
}
