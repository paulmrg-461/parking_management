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

      final time = await http
          .get(Uri.parse('$gateway/v1/time'))
          .timeout(const Duration(seconds: 15));
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
        return http
            .post(
              Uri.parse('$gateway/v1/heartbeat'),
              headers: {
                'Content-Type': 'application/json',
                'X-Device-Key': key,
                'X-Device-Timestamp': '$timestamp',
                'X-Device-Seq': '$seq',
                'X-Device-Firmware': 'e2e-1.0',
              },
              body: jsonEncode({'status': status}),
            )
            .timeout(const Duration(seconds: 15));
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

      // LPR routes: assign the direction, read the config and post one read.
      await client.rpc('set_lpr_camera_direction', params: {
        'p_device_id': deviceId,
        'p_direction': 'entry',
      });
      final config = await http
          .get(
            Uri.parse('$gateway/v1/lpr/config'),
            headers: {
              'X-Device-Key': key,
              'X-Device-Timestamp': '$now',
              'X-Device-Seq': '4',
            },
          )
          .timeout(const Duration(seconds: 15));
      expect(config.statusCode, 200);
      expect(
        (jsonDecode(config.body) as Map<String, dynamic>)['direction'],
        'entry',
      );

      final plate = 'E2E${DateTime.now().millisecondsSinceEpoch % 100000}';
      Future<Map<String, dynamic>> postRead(int seq) async {
        final reference = _Uuid().next();
        final response = await http
            .post(
              Uri.parse('$gateway/v1/lpr/reads'),
              headers: {
                'Content-Type': 'application/json',
                'X-Device-Key': key,
                'X-Device-Timestamp': '$now',
                'X-Device-Seq': '$seq',
                'Idempotency-Key': reference,
              },
              body: jsonEncode({
                'client_ref': reference,
                'plate': plate,
                'confidence': 0.93,
                'captured_at': DateTime.now().toUtc().toIso8601String(),
                'track_id': 'e2e-track',
              }),
            )
            .timeout(const Duration(seconds: 15));
        expect(response.statusCode, 200);
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final firstRead = await postRead(5);
      expect(firstRead['outcome'], 'recorded');
      expect(firstRead['event'], isNull);
      await postRead(6);
      final third = await postRead(7);
      expect(third['outcome'], 'decided');
      expect(third['snapshot_wanted'], isTrue);
      final event = third['event'] as Map<String, dynamic>;
      expect(event['status'], 'pending');
      expect(event['reason'], 'assist_mode');
      expect(event['plate'], plate);

      // 1x1 JPEG: the route checks the magic bytes and Storage keeps it.
      final jpeg = base64Decode(
        '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a'
        'HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAA'
        'AAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
      );
      final snapshot = await http
          .put(
            Uri.parse('$gateway/v1/lpr/events/${event['id']}/snapshot'),
            headers: {
              'Content-Type': 'image/jpeg',
              'X-Device-Key': key,
              'X-Device-Timestamp': '$now',
              'X-Device-Seq': '8',
            },
            body: jpeg,
          )
          .timeout(const Duration(seconds: 20));
      expect(snapshot.statusCode, 200);
      final attached = jsonDecode(snapshot.body) as Map<String, dynamic>;
      expect(attached['event_id'], event['id']);
      expect(attached['session_id'], isNull);

      // Barrier routes: configured timings and a signed-command poll.
      final barrierName = 'e2e-barrier-${DateTime.now().millisecondsSinceEpoch}';
      final barrier = Map<String, dynamic>.from(
        await client.rpc('register_lot_device', params: {
          'p_kind': 'barrier',
          'p_name': barrierName,
        }) as Map,
      );
      final barrierKey = barrier['api_key'] as String;
      final barrierId = barrier['id'] as int;
      addTearDown(() async {
        try {
          await client.rpc('delete_lot_device', params: {'p_id': barrierId});
        } catch (_) {}
      });
      await client.rpc('set_barrier_config', params: {
        'p_device_id': barrierId,
        'p_direction': 'entry',
        'p_open_hold_ms': 1000,
      });
      // A heartbeat marks the barrier online before a manual open.
      final barrierBeat = await http
          .post(
            Uri.parse('$gateway/v1/heartbeat'),
            headers: {
              'Content-Type': 'application/json',
              'X-Device-Key': barrierKey,
              'X-Device-Timestamp': '$now',
              'X-Device-Seq': '1',
            },
            body: jsonEncode({'status': {'uptime_s': 1}}),
          )
          .timeout(const Duration(seconds: 15));
      expect(barrierBeat.statusCode, 200);

      final barrierConfig = await http
          .get(
            Uri.parse('$gateway/v1/barrier/config'),
            headers: {
              'X-Device-Key': barrierKey,
              'X-Device-Timestamp': '$now',
              'X-Device-Seq': '2',
            },
          )
          .timeout(const Duration(seconds: 15));
      expect(barrierConfig.statusCode, 200);
      final configBody = jsonDecode(barrierConfig.body) as Map<String, dynamic>;
      expect(configBody['direction'], 'entry');
      expect(configBody['open_hold_ms'], 1000);
      expect(configBody['command_ttl_s'], 30);

      final manual = Map<String, dynamic>.from(
        await client.rpc('request_manual_barrier_open', params: {
          'p_device_id': barrierId,
          'p_reason': 'E2E manual open',
        }) as Map,
      );
      final commandId = manual['command_id'] as String;

      final poll = await http
          .get(
            Uri.parse('$gateway/v1/barrier/commands/next?wait=0'),
            headers: {
              'X-Device-Key': barrierKey,
              'X-Device-Timestamp': '$now',
              'X-Device-Seq': '3',
            },
          )
          .timeout(const Duration(seconds: 15));
      expect(poll.statusCode, 200);
      final polled = jsonDecode(poll.body) as Map<String, dynamic>;
      final command = polled['command'] as Map<String, dynamic>;
      expect(command['id'], commandId);
      expect(command['hold_ms'], 1000);
      expect(command['max_open_s'], 20);
      expect((command['signature'] as String).isNotEmpty, isTrue);
      expect((command['issued_at'] as int) > 0, isTrue);

      final ack = await http
          .post(
            Uri.parse('$gateway/v1/barrier/commands/$commandId/ack'),
            headers: {
              'Content-Type': 'application/json',
              'X-Device-Key': barrierKey,
              'X-Device-Timestamp': '$now',
              'X-Device-Seq': '4',
              'Idempotency-Key': commandId,
            },
            body: jsonEncode({'result': 'opened', 'open_ms': 1234}),
          )
          .timeout(const Duration(seconds: 15));
      expect(ack.statusCode, 200);
      expect(
        (jsonDecode(ack.body) as Map<String, dynamic>)['status'],
        'executed',
      );

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

class _Uuid {
  int _counter = 0;

  String next() {
    // Deterministic v4-shaped UUID for the read idempotency key.
    final suffix = (DateTime.now().microsecondsSinceEpoch + _counter++)
        .toRadixString(16)
        .padLeft(12, '0');
    return '0b6f6d5c-3d4e-4a53-9a0e-${suffix.substring(suffix.length - 12)}';
  }
}
