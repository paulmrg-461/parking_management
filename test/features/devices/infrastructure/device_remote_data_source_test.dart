import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/devices/domain/entities/lot_device.dart';
import 'package:parking_management/features/devices/infrastructure/device_remote_data_source.dart';

void main() {
  test('list maps the payload', () async {
    final remote = SupabaseDeviceRemoteDataSource((name, params) async => {
      'offline_minutes': 10,
      'devices': [
        {'id': 1, 'kind': 'camera', 'name': 'C', 'status': 'online'},
      ],
    });
    final list = await remote.list();
    expect(list.offlineMinutes, 10);
    expect(list.devices.single.name, 'C');
  });

  test('register sends the kind and name', () async {
    Map<String, dynamic>? sent;
    final remote = SupabaseDeviceRemoteDataSource((name, params) async {
      sent = params;
      return {'id': 2, 'kind': 'barrier', 'name': 'B', 'api_key': 'pkd_key'};
    });
    final device = await remote.register(kind: DeviceKind.barrier, name: 'B');
    expect(device.apiKey, 'pkd_key');
    expect(sent?['p_kind'], 'barrier');
  });

  test('rotate, update, delete and events map', () async {
    final calls = <String>[];
    final remote = SupabaseDeviceRemoteDataSource((name, params) async {
      calls.add(name);
      if (name == 'list_device_events') {
        return [
          {'id': 1, 'event': 'registered'},
        ];
      }
      if (name == 'set_device_offline_minutes') {
        return {'offline_minutes': 7};
      }
      if (name == 'delete_lot_device') return null;
      return {'id': 3, 'kind': 'camera', 'name': 'X', 'api_key': 'pkd_k'};
    });
    expect((await remote.rotate(3)).apiKey, 'pkd_k');
    await remote.update(3, name: 'Y', enabled: false, ratePerMinute: 60);
    await remote.delete(3);
    expect((await remote.events(3)).single.event, 'registered');
    expect(await remote.setOfflineMinutes(7), 7);
    expect(calls, contains('rotate_lot_device_key'));
  });

  test('a typed RPC error becomes a Failure with its code', () {
    final remote = SupabaseDeviceRemoteDataSource((name, params) async {
      throw Exception('DeviceNotFoundError');
    });
    expect(
      () => remote.delete(1),
      throwsA(isA<Failure>()),
    );
  });
}
