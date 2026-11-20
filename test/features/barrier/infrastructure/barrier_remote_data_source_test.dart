import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/barrier/domain/commands/barrier_config_update.dart';
import 'package:parking_management/features/barrier/domain/entities/barrier.dart';
import 'package:parking_management/features/barrier/infrastructure/barrier_remote_data_source.dart';

Map<String, dynamic> barrierJson() => {
  'device_id': 7,
  'name': 'Salida',
  'status': 'online',
  'direction': 'exit',
  'config': {'direction': 'exit'},
};

void main() {
  test('list maps the barriers', () async {
    final remote = SupabaseBarrierRemoteDataSource(
      (name, params) async => [barrierJson()],
    );
    final barriers = await remote.list();
    expect(barriers.single.name, 'Salida');
  });

  test('open sends the trimmed reason and fetches the command', () async {
    final calls = <String>[];
    final remote = SupabaseBarrierRemoteDataSource((name, params) async {
      calls.add(name);
      if (name == 'request_manual_barrier_open') {
        expect(params['p_reason'], 'Cliente sin ticket');
        return {'command_id': 'c1', 'expires_at': 'x'};
      }
      return {
        'id': 'c1',
        'source': 'manual',
        'status': 'queued',
        'issued_at': '2026-11-20T09:59:00Z',
        'expires_at': '2026-11-20T09:59:30Z',
      };
    });
    final command = await remote.open(7, '  Cliente sin ticket  ');
    expect(command.id, 'c1');
    expect(calls, ['request_manual_barrier_open', 'get_barrier_command']);
  });

  test('history sends the device filter', () async {
    final remote = SupabaseBarrierRemoteDataSource((name, params) async {
      expect(params['p_device_id'], 7);
      return [
        {
          'id': 'c1',
          'source': 'manual',
          'status': 'executed',
          'issued_at': '2026-11-20T09:59:00Z',
          'expires_at': '2026-11-20T09:59:30Z',
        },
      ];
    });
    expect((await remote.history(7)).single.status.name, 'executed');
  });

  test('saveConfig sends the fields and re-reads the barrier', () async {
    Map<String, dynamic>? sent;
    final remote = SupabaseBarrierRemoteDataSource((name, params) async {
      if (name == 'set_barrier_config') {
        sent = params;
        return {'device_id': 7};
      }
      return [barrierJson()];
    });
    final barrier = await remote.saveConfig(
      const BarrierConfigUpdate(
        deviceId: 7,
        direction: BarrierDirection.entry,
        openOnCheckin: 'always',
        openForPassEntry: true,
        openHoldMs: 900,
      ),
    );
    expect(barrier.deviceId, 7);
    expect(sent?['p_direction'], 'entry');
    expect(sent?['p_open_on_checkin'], 'always');
    expect(sent?['p_open_hold_ms'], 900);
  });

  test('a typed error becomes a Failure with its code', () {
    final remote = SupabaseBarrierRemoteDataSource(
      (name, params) async => throw Exception('BarrierBusyError'),
    );
    expect(() => remote.list(), throwsA(isA<Failure>()));
  });
}
