@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

/// End-to-end smoke against a REAL stack, using the same client the app uses.
///
/// Skipped unless the environment points at a running stack:
///
/// ```bash
/// SUPABASE_URL=http://localhost:8000 \
/// SUPABASE_ANON_KEY=$(grep '^ANON_KEY=' .env | cut -d= -f2-) \
/// flutter test test/integration
/// ```
///
/// It signs in, checks a plate in, checks it out with cash, then reads the
/// revenue report and the vehicle history. Every run uses a unique plate, so
/// repeated executions are safe; the rows stay in the (disposable) database.
void main() {
  final url = Platform.environment['SUPABASE_URL'];
  final anonKey = Platform.environment['SUPABASE_ANON_KEY'];
  final username = Platform.environment['E2E_USERNAME'] ?? 'admin';
  final pin = Platform.environment['E2E_PIN'] ?? '123456';
  final skipReason = url == null || anonKey == null
      ? 'SUPABASE_URL/SUPABASE_ANON_KEY not set'
      : null;

  test(
    'login → check-in → check-out → report → history',
    skip: skipReason,
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      final client = SupabaseClient(url!, anonKey!);
      addTearDown(client.dispose);

      final auth = await client.auth.signInWithPassword(
        email: '$username@parking.local',
        password: pin,
      );
      expect(auth.session, isNotNull);

      final lots = await client.rpc('my_lots') as List<dynamic>;
      expect(lots, isNotEmpty, reason: 'the user must belong to a lot');

      // No x-lot-id header is sent: the server uses the lowest membership, so
      // the test targets the same lot explicitly.
      final lotId = lots
          .map((lot) => (lot as Map<String, dynamic>)['id'] as int)
          .reduce((a, b) => a < b ? a : b);
      // The header is mandatory: every lot-scoped request must select a lot
      // the user belongs to.
      client.headers = {...client.headers, 'x-lot-id': '$lotId'};
      final categoryId = await _ensureTariff(client, lotId);
      final plate = 'E2E${DateTime.now().millisecondsSinceEpoch % 1000000}';

      final checkedIn = Map<String, dynamic>.from(
        await client.rpc(
          'check_in',
          params: {
            'p_plate': plate,
            'p_category_id': categoryId,
            'p_photos': <Map<String, Object?>>[],
            'p_idempotency_key': 'e2e-in-$plate',
          },
        ) as Map,
      );
      expect(checkedIn['status'], 'open');
      expect(checkedIn['lot_id'], lotId);

      final checkedOut = Map<String, dynamic>.from(
        await client.rpc(
          'check_out',
          params: {
            'p_session_id': checkedIn['id'],
            'p_payment_method': 'cash',
            'p_idempotency_key': 'e2e-out-$plate',
          },
        ) as Map,
      );
      expect(checkedOut['amount_charged'], isA<int>());
      expect(checkedOut['ticket_number'], startsWith('TCK-'));

      final today = DateTime.now();
      final report = Map<String, dynamic>.from(
        await client.rpc(
          'report_revenue',
          params: {
            'p_start_date': _date(today),
            'p_end_date': _date(today),
          },
        ) as Map,
      );
      expect(report['total'], greaterThanOrEqualTo(checkedOut['amount_charged']));

      final history = Map<String, dynamic>.from(
        await client.rpc('vehicle_history', params: {'p_plate': plate}) as Map,
      );
      expect(history['plate'], plate.replaceAll(' ', ''));
      expect(history['visits'], greaterThanOrEqualTo(1));

      await client.auth.signOut();
    },
  );
}

/// A check-out needs an active hourly tariff. The seed only creates
/// categories, so the e2e adds one per lot when missing.
Future<int> _ensureTariff(SupabaseClient client, int lotId) async {
  final rows = await client
      .from('categories')
      .select('id')
      .eq('lot_id', lotId)
      .eq('name', 'car')
      .limit(1);
  final categoryId = rows.isEmpty ? null : rows.first['id'] as int?;
  if (categoryId == null) {
    throw StateError('category "car" missing for lot $lotId');
  }

  final tariffs = await client
      .from('tariffs')
      .select('id')
      .eq('category_id', categoryId)
      .eq('type', 'hourly')
      .eq('active', true)
      .limit(1);
  if (tariffs.isEmpty) {
    await client.from('tariffs').insert({
      'category_id': categoryId,
      'lot_id': lotId,
      'type': 'hourly',
      'amount': 5000,
      'active': true,
    });
  }
  return categoryId;
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
