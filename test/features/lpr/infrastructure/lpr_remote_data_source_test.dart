import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/lpr/domain/commands/confirm_lpr_entry.dart';
import 'package:parking_management/features/lpr/domain/commands/lpr_settings_update.dart';
import 'package:parking_management/features/lpr/domain/entities/lpr_settings.dart';
import 'package:parking_management/features/lpr/infrastructure/lpr_remote_data_source.dart';

void main() {
  test('listEvents sends the status filter and maps the array', () async {
    Map<String, dynamic>? sent;
    final remote = SupabaseLprRemoteDataSource((name, params) async {
      sent = params;
      return [
        {
          'id': 1,
          'kind': 'exit',
          'status': 'pending',
          'reason': 'exit_unpaid',
          'plate': 'ABC123',
          'confidence': 0.9,
          'votes': 3,
          'has_pass': true,
          'created_at': '2026-11-19T10:00:00Z',
        },
      ];
    }, (path) async => Uint8List(0));
    final events = await remote.listEvents(status: 'pending');
    expect(events.single.isEntry, isFalse);
    expect(events.single.hasPass, isTrue);
    expect(sent?['p_status'], 'pending');
  });

  test('confirm sends the correction and maps the session', () async {
    Map<String, dynamic>? sent;
    final remote = SupabaseLprRemoteDataSource((name, params) async {
      sent = params;
      return {
        'id': 88,
        'plate': 'XYZ987',
        'status': 'open',
        'entry_time': '2026-11-19T10:00:00Z',
        'photo_count': 0,
        'event_id': 4,
      };
    }, (path) async => Uint8List(0));
    final dto = await remote.confirm(
      eventId: 4,
      plate: 'XYZ987',
      categoryId: 2,
    );
    expect(dto.toDomain().id, 88);
    expect(sent?['p_event_id'], 4);
    expect(sent?['p_plate'], 'XYZ987');
    expect(sent?['p_category_id'], 2);
  });

  test('dismiss sends the note and returns nothing', () async {
    Map<String, dynamic>? sent;
    final remote = SupabaseLprRemoteDataSource((name, params) async {
      sent = params;
      return {'event_id': 4, 'status': 'dismissed'};
    }, (path) async => Uint8List(0));
    await remote.dismiss(4, note: 'placa ajena');
    expect(sent?['p_note'], 'placa ajena');
  });

  test('snapshot downloads through the injected client', () async {
    final remote = SupabaseLprRemoteDataSource(
      (name, params) async => null,
      (path) async {
        expect(path, 'lpr/1/7/4.jpg');
        return Uint8List.fromList([1, 2]);
      },
    );
    expect((await remote.snapshot('lpr/1/7/4.jpg')).length, 2);
  });

  test('a typed RPC error becomes a Failure', () {
    final remote = SupabaseLprRemoteDataSource(
      (name, params) async => throw Exception('LprEventResolvedError'),
      (path) async => Uint8List(0),
    );
    expect(() => remote.dismiss(4), throwsA(isA<Failure>()));
  });

  test('repository confirm maps the DTO to the domain session', () async {
    final repository = LprRepositoryImpl(
      SupabaseLprRemoteDataSource((name, params) async => {
        'id': 88,
        'plate': 'ABC123',
        'status': 'open',
        'entry_time': '2026-11-19T10:00:00Z',
        'photo_count': 0,
      }, (path) async => Uint8List(0)),
    );
    final session = await repository.confirmEntry(
      const ConfirmLprEntry(eventId: 4),
    );
    expect(session.id, 88);
  });
}

void settingsTests() {
  test('settings maps the payload and cameras', () async {
    final remote = SupabaseLprRemoteDataSource((name, params) async {
      expect(name, 'get_lpr_settings');
      return {
        'mode': 'assist',
        'min_confidence': 0.8,
        'auto_confidence': 0.92,
        'min_votes': 3,
        'vote_window_seconds': 8,
        'cooldown_seconds': 120,
        'cameras': [],
      };
    }, (path) async => Uint8List(0));
    final settings = await remote.settings();
    expect(settings.mode.name, 'assist');
    expect(settings.cameras, isEmpty);
  });

  test('saveSettings sends only the provided fields', () async {
    Map<String, dynamic>? sent;
    final remote = SupabaseLprRemoteDataSource((name, params) async {
      sent = params;
      return {'mode': 'auto', 'min_votes': 3};
    }, (path) async => Uint8List(0));
    await remote.saveSettings(
      const LprSettingsUpdate(mode: LprMode.auto, actingUserId: 7),
    );
    expect(sent?['p_mode'], 'auto');
    expect(sent?['p_acting_user_id'], 7);
    expect(sent?['p_min_votes'], isNull);
  });

  test('setCameraDirection sends the device and direction', () async {
    Map<String, dynamic>? sent;
    final remote = SupabaseLprRemoteDataSource((name, params) async {
      sent = params;
      return {'device_id': 4, 'direction': 'exit'};
    }, (path) async => Uint8List(0));
    await remote.setCameraDirection(4, 'exit');
    expect(sent?['p_device_id'], 4);
    expect(sent?['p_direction'], 'exit');
  });
}
