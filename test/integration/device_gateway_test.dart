@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

/// End-to-end smoke of the device credential path against a REAL stack, with
/// no hardware: an admin registers a device, then a plain HTTP client (like
/// firmware) calls `/v1/time` and `/v1/heartbeat` and hits the replay, clock
/// skew and bad-key branches. Skipped unless the stack is configured:
///
/// ```bash
/// SUPABASE_URL=http://localhost:8017 \
/// SUPABASE_ANON_KEY=$(grep '^ANON_KEY=' .env | cut -d= -f2-) \
/// flutter test test/integration/device_gateway_test.dart
/// ```
void main() {
  final url = Platform.environment['SUPABASE_URL'];
  final anonKey = Platform.environment['SUPABASE_ANON_KEY'];
  final username = Platform.environment['E2E_USERNAME'] ?? 'admin';
  final pin = Platform.environment['E2E_PIN'] ?? '123456';
  final gateway = Platform.environment['DEVICE_GATEWAY_URL'] ??
      (url == null ? null : '$url/functions/v1/device-gateway');
  final skipReason = url == null || anonKey == null || gateway == null
      ? 'SUPABASE_URL/SUPABASE_ANON_KEY not set'
      : null;

  test(
    'device key, heartbeat, replay, clock skew and bad key',
    skip: skipReason,
    timeout: const Timeout(Duration(minutes: 2)),
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
      final lotId = lots
          .map((lot) => (lot as Map<String, dynamic>)['id'] as int)
          .reduce((a, b) => a < b ? a : b);
      client.headers = {...client.headers, 'x-lot-id': '$lotId'};

      final name = 'e2e-${DateTime.now().millisecondsSinceEpoch}';
      final registered = Map<String, dynamic>.from(
        await client.rpc('register_lot_device', params: {
          'p_kind': 'camera',
          'p_name': name,
        }) as Map,
      );
      final key = registered['api_key'] as String;
      final deviceId = registered['id'] as int;
      expect(key, matches(RegExp(r'^pkd_[0-9a-f]{12}_[0-9a-f]{64}$')));
      addTearDown(() async {
        try {
          await client.rpc('delete_lot_device', params: {'p_id': deviceId});
        } catch (_) {
          // The device may already be gone; cleanup is best effort.
        }
      });

      final time = await http.get(Uri.parse('$gateway/v1/time'));
      expect(time.statusCode, 200);
      final timeBody = jsonDecode(time.body) as Map<String, dynamic>;
      expect(timeBody['max_skew_s'], 300);
      expect(timeBody['server_time'], isA<String>());

      Future<http.Response> beat({
        required String key,
        required int seq,
        required int timestamp,
        Map<String, Object?> status = const {'uptime_s': 5},
      }) {
        return http.post(
          Uri.parse('$gateway/v1/heartbeat'),
          headers: {
            'Content-Type': 'application/json',
            'X-Device-Key': key,
            'X-Device-Timestamp': '$timestamp',
            'X-Device-Seq': '$seq',
            'X-Device-Firmware': 'e2e-1.0',
          },
          body: jsonEncode({'status': status}),
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final first = await beat(key: key, seq: 1, timestamp: now);
      expect(first.statusCode, 200);
      final firstBody = jsonDecode(first.body) as Map<String, dynamic>;
      expect(firstBody['heartbeat_interval_s'], 60);
      expect((firstBody['device'] as Map<String, dynamic>)['id'], deviceId);
      expect(
        (firstBody['device'] as Map<String, dynamic>)['lot_id'],
        lotId,
      );

      final replay = await beat(key: key, seq: 1, timestamp: now);
      expect(replay.statusCode, 409);
      expect(
        (jsonDecode(replay.body) as Map<String, dynamic>)['error'],
        'DeviceReplayError',
      );

      final skew = await beat(key: key, seq: 2, timestamp: 1);
      expect(skew.statusCode, 400);
      expect(
        (jsonDecode(skew.body) as Map<String, dynamic>)['error'],
        'DeviceClockSkewError',
      );

      final tampered = _tamper(key);
      final bad = await beat(key: tampered, seq: 3, timestamp: now);
      expect(bad.statusCode, 401);
      expect(
        (jsonDecode(bad.body) as Map<String, dynamic>)['message'],
        'DeviceUnauthorizedError',
      );

      final recovered = await beat(key: key, seq: 3, timestamp: now);
      expect(recovered.statusCode, 200);

      final events = await client.rpc('list_device_events', params: {
        'p_device_id': deviceId,
        'p_limit': 20,
      }) as List<dynamic>;
      final kinds = events
          .map((event) => (event as Map<String, dynamic>)['event'])
          .toSet();
      expect(kinds, containsAll(['registered', 'request_rejected', 'auth_failed']));
    },
  );
}

String _tamper(String key) {
  final last = key.substring(key.length - 1);
  return key.substring(0, key.length - 1) + (last == '0' ? '1' : '0');
}
