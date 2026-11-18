import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/devices/domain/entities/lot_device.dart';

void main() {
  test('parses a device and its secret once', () {
    final device = LotDevice.fromJson(const {
      'id': 7,
      'kind': 'barrier',
      'name': 'Barrera',
      'key_prefix': '3fa94c0b12de',
      'status': 'offline',
      'last_status': {'uptime_s': 10},
      'api_key': 'pkd_key',
    });
    expect(device.kind, DeviceKind.barrier);
    expect(device.status, DeviceStatus.offline);
    expect(device.apiKey, 'pkd_key');
    expect(device.lastStatus['uptime_s'], 10);
  });

  test('unknown values fall back safely', () {
    final device = LotDevice.fromJson(const {'kind': 'x', 'status': 'x'});
    expect(device.kind, DeviceKind.camera);
    expect(device.status, DeviceStatus.neverSeen);
    expect(device.apiKey, isNull);
  });
}
