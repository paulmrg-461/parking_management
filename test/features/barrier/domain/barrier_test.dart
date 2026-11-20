import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/barrier/domain/entities/barrier.dart';
import 'package:parking_management/features/barrier/domain/entities/barrier_command.dart';
import 'package:parking_management/features/devices/domain/entities/lot_device.dart';

Map<String, dynamic> barrierJson() => {
  'device_id': 7,
  'name': 'Salida',
  'enabled': true,
  'status': 'online',
  'direction': 'exit',
  'last_seen_at': '2026-11-20T10:00:00Z',
  'firmware_version': 'barrier-1.0.0',
  'camera_device_id': 3,
  'camera_name': 'Cam salida',
  'config': {
    'direction': 'exit',
    'open_on_checkin': 'always',
    'open_on_paid_exit': 'never',
    'open_for_pass_entry': true,
    'open_hold_ms': 900,
    'max_open_seconds': 25,
    'post_clear_delay_ms': 2000,
    'max_reversals': 4,
    'command_ttl_seconds': 45,
  },
  'in_flight': null,
  'last_command': {
    'id': '6f1c1d8e-0b34-4d44-8a3e-6f5c1c1d9a10',
    'source': 'paid_exit',
    'status': 'executed',
    'issued_at': '2026-11-20T09:59:00Z',
    'expires_at': '2026-11-20T09:59:30Z',
    'result': {'result': 'opened', 'open_ms': 4210},
  },
};

void main() {
  test('parses a barrier with its config and last command', () {
    final barrier = Barrier.fromJson(barrierJson());
    expect(barrier.deviceId, 7);
    expect(barrier.name, 'Salida');
    expect(barrier.status, DeviceStatus.online);
    expect(barrier.direction, BarrierDirection.exit);
    expect(barrier.online, isTrue);
    expect(barrier.config?.openHoldMs, 900);
    expect(barrier.config?.openForPassEntry, isTrue);
    expect(barrier.lastCommand?.source, BarrierSource.paidExit);
    expect(barrier.lastCommand?.status, BarrierCommandStatus.executed);
    expect(barrier.lastCommand?.result['open_ms'], 4210);
    expect(barrier.cameraName, 'Cam salida');
  });

  test('an unknown command status is a format error', () {
    expect(
      () => BarrierCommand.fromJson({
        'id': 'x',
        'source': 'manual',
        'status': 'exploded',
        'issued_at': '2026-11-20T09:59:00Z',
        'expires_at': '2026-11-20T09:59:30Z',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('terminal statuses are recognised', () {
    for (final status in BarrierCommandStatus.values) {
      expect(
        status.isTerminal,
        status != BarrierCommandStatus.queued &&
            status != BarrierCommandStatus.delivered,
      );
    }
    expect(BarrierCommandStatus.executed.succeeded, isTrue);
    expect(BarrierCommandStatus.rejected.succeeded, isFalse);
  });
}
