import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/devices/domain/entities/lot_device.dart';
import 'package:parking_management/features/lpr/domain/entities/lpr_settings.dart';

void main() {
  test('parses the settings and the camera list', () {
    final settings = LprSettings.fromJson({
      'mode': 'auto',
      'min_confidence': 0.85,
      'auto_confidence': 0.94,
      'min_votes': 4,
      'vote_window_seconds': 10,
      'cooldown_seconds': 180,
      'default_category_id': 2,
      'acting_user_id': 7,
      'cameras': [
        {
          'device_id': 3,
          'name': 'Entrada',
          'direction': 'entry',
          'status': 'online',
        },
        {'device_id': 4, 'name': 'Salida', 'direction': null, 'status': 'never_seen'},
      ],
    });
    expect(settings.isAuto, isTrue);
    expect(settings.minConfidence, 0.85);
    expect(settings.autoConfidence, 0.94);
    expect(settings.minVotes, 4);
    expect(settings.voteWindowSeconds, 10);
    expect(settings.cooldownSeconds, 180);
    expect(settings.defaultCategoryId, 2);
    expect(settings.actingUserId, 7);
    expect(settings.cameras, hasLength(2));
    expect(settings.cameras.first.direction, 'entry');
    expect(settings.cameras.first.status, DeviceStatus.online);
    expect(settings.cameras.last.direction, isNull);
    expect(settings.cameras.last.status, DeviceStatus.neverSeen);
  });

  test('defaults to assist when the payload is sparse', () {
    final settings = LprSettings.fromJson({});
    expect(settings.mode, LprMode.assist);
    expect(settings.hasCameras, isFalse);
    expect(settings.minVotes, 3);
  });
}
