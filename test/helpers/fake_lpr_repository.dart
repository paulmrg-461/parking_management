import 'dart:typed_data';

import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/lpr/domain/commands/confirm_lpr_entry.dart';
import 'package:parking_management/features/lpr/domain/entities/lpr_event.dart';
import 'package:parking_management/features/lpr/domain/repositories/lpr_repository.dart';

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
}
