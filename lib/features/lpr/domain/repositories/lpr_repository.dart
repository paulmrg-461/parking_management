import 'dart:typed_data';

import '../../../check_in/domain/entities/parking_session.dart';
import '../commands/confirm_lpr_entry.dart';
import '../commands/lpr_settings_update.dart';
import '../entities/lpr_event.dart';
import '../entities/lpr_settings.dart';

abstract class LprRepository {
  Future<List<LprEvent>> listEvents({String status = 'pending'});

  Future<ParkingSession> confirmEntry(ConfirmLprEntry command);

  Future<void> dismiss(int eventId, {String? note});

  Future<Uint8List> snapshot(String path);

  Future<LprSettings> settings();

  Future<LprSettings> saveSettings(LprSettingsUpdate update);

  Future<void> setCameraDirection({
    required int deviceId,
    required String direction,
  });
}
