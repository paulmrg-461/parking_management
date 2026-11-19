import 'dart:typed_data';

import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/devices/domain/entities/lot_device.dart';
import 'package:parking_management/features/lpr/domain/commands/confirm_lpr_entry.dart';
import 'package:parking_management/features/lpr/domain/commands/lpr_settings_update.dart';
import 'package:parking_management/features/lpr/domain/entities/lpr_settings.dart';
import 'package:parking_management/features/lpr/domain/entities/lpr_event.dart';
import 'package:parking_management/features/lpr/domain/repositories/lpr_repository.dart';

LprSettings fakeLprSettings({List<LprCamera>? cameras}) => LprSettings(
  mode: LprMode.assist,
  minConfidence: 0.8,
  autoConfidence: 0.92,
  minVotes: 3,
  voteWindowSeconds: 8,
  cooldownSeconds: 120,
  defaultCategoryId: null,
  actingUserId: null,
  cameras: cameras ??
      const [
        LprCamera(
          deviceId: 3,
          name: 'Entrada',
          direction: 'entry',
          status: DeviceStatus.online,
        ),
      ],
);

LprEvent fakeLprEvent({
  int id = 1,
  LprEventKind kind = LprEventKind.entry,
  LprEventStatus status = LprEventStatus.pending,
  LprEventReason? reason = LprEventReason.assistMode,
  String plate = 'ABC123',
  int? sessionId,
}) {
  return LprEvent(
    id: id,
    kind: kind,
    status: status,
    reason: reason,
    plate: plate,
    confidence: 0.95,
    votes: 3,
    sessionId: sessionId,
    hasPass: false,
    snapshotPath: null,
    deviceName: 'Entrada',
    createdAt: DateTime(2026, 11, 19, 10),
  );
}

class FakeLprRepository implements LprRepository {
  List<LprEvent> events = [fakeLprEvent()];
  Failure? listError;
  Failure? confirmError;
  Failure? dismissError;
  int listCalls = 0;
  final List<ConfirmLprEntry> confirmed = [];
  final List<int> dismissed = [];
  LprSettings settingsValue = fakeLprSettings();
  Failure? settingsError;
  Failure? saveError;
  Failure? directionError;
  final List<LprSettingsUpdate> saved = [];
  final List<(int, String)> directions = [];

  @override
  Future<List<LprEvent>> listEvents({String status = 'pending'}) async {
    listCalls += 1;
    if (listError case final error?) throw error;
    return List.of(events);
  }

  @override
  Future<ParkingSession> confirmEntry(ConfirmLprEntry command) async {
    if (confirmError case final error?) throw error;
    confirmed.add(command);
    events = [
      for (final event in events) if (event.id != command.eventId) event,
    ];
    return ParkingSession(
      id: 88,
      plate: command.plate ?? 'ABC123',
      status: ParkingSessionStatus.open,
      entryTime: DateTime(2026, 11, 19, 10),
      photoCount: 0,
    );
  }

  @override
  Future<void> dismiss(int eventId, {String? note}) async {
    if (dismissError case final error?) throw error;
    dismissed.add(eventId);
    events = [for (final event in events) if (event.id != eventId) event];
  }

  @override
  Future<Uint8List> snapshot(String path) async => Uint8List(0);

  @override
  Future<LprSettings> settings() async {
    if (settingsError case final error?) throw error;
    return settingsValue;
  }

  @override
  Future<LprSettings> saveSettings(LprSettingsUpdate update) async {
    if (saveError case final error?) throw error;
    saved.add(update);
    settingsValue = LprSettings(
      mode: update.mode ?? settingsValue.mode,
      minConfidence: update.minConfidence ?? settingsValue.minConfidence,
      autoConfidence: update.autoConfidence ?? settingsValue.autoConfidence,
      minVotes: update.minVotes ?? settingsValue.minVotes,
      voteWindowSeconds:
          update.voteWindowSeconds ?? settingsValue.voteWindowSeconds,
      cooldownSeconds: update.cooldownSeconds ?? settingsValue.cooldownSeconds,
      defaultCategoryId:
          update.defaultCategoryId ?? settingsValue.defaultCategoryId,
      actingUserId: update.actingUserId ?? settingsValue.actingUserId,
      cameras: settingsValue.cameras,
    );
    return settingsValue;
  }

  @override
  Future<void> setCameraDirection({
    required int deviceId,
    required String direction,
  }) async {
    if (directionError case final error?) throw error;
    directions.add((deviceId, direction));
    settingsValue = LprSettings(
      mode: settingsValue.mode,
      minConfidence: settingsValue.minConfidence,
      autoConfidence: settingsValue.autoConfidence,
      minVotes: settingsValue.minVotes,
      voteWindowSeconds: settingsValue.voteWindowSeconds,
      cooldownSeconds: settingsValue.cooldownSeconds,
      defaultCategoryId: settingsValue.defaultCategoryId,
      actingUserId: settingsValue.actingUserId,
      cameras: [
        for (final camera in settingsValue.cameras)
          camera.deviceId == deviceId
              ? LprCamera(
                  deviceId: camera.deviceId,
                  name: camera.name,
                  direction: direction,
                  status: camera.status,
                )
              : camera,
      ],
    );
  }
}
