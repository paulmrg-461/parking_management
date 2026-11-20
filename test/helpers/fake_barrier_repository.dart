import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/barrier/domain/commands/barrier_config_update.dart';
import 'package:parking_management/features/barrier/domain/commands/open_barrier_request.dart';
import 'package:parking_management/features/barrier/domain/entities/barrier.dart';
import 'package:parking_management/features/barrier/domain/entities/barrier_command.dart';
import 'package:parking_management/features/barrier/domain/repositories/barrier_repository.dart';
import 'package:parking_management/features/devices/domain/entities/lot_device.dart';

BarrierCommand fakeBarrierCommand({
  String id = '6f1c1d8e-0b34-4d44-8a3e-6f5c1c1d9a10',
  BarrierSource source = BarrierSource.manual,
  BarrierCommandStatus status = BarrierCommandStatus.executed,
  String? requestedByName = 'Ana',
  String? reason,
}) {
  return BarrierCommand(
    id: id,
    deviceId: 1,
    deviceName: 'Salida',
    source: source,
    status: status,
    reason: reason,
    requestedByName: requestedByName,
    issuedAt: DateTime(2026, 11, 20, 10),
    expiresAt: DateTime(2026, 11, 20, 10, 0, 30),
    result: const {'result': 'opened'},
  );
}

Barrier fakeBarrier({
  int deviceId = 1,
  String name = 'Salida',
  DeviceStatus status = DeviceStatus.online,
  BarrierDirection direction = BarrierDirection.exit,
  BarrierCommand? lastCommand,
  BarrierCommand? inFlight,
}) {
  return Barrier(
    deviceId: deviceId,
    name: name,
    status: status,
    direction: direction,
    config: BarrierConfig(
      direction: direction,
      openOnCheckin: 'lpr_only',
      openOnPaidExit: 'lpr_only',
    ),
    lastCommand: lastCommand,
    inFlight: inFlight,
  );
}

class FakeBarrierRepository implements BarrierRepository {
  List<Barrier> barriers = [fakeBarrier()];
  List<BarrierCommand> historyItems = [fakeBarrierCommand()];
  Failure? listError;
  Failure? openError;
  Failure? commandError;
  Failure? saveError;

  /// Statuses returned by [command] in order (the last one repeats).
  List<BarrierCommandStatus> pollStatuses = const [BarrierCommandStatus.executed];
  int commandCalls = 0;
  int listCalls = 0;
  final List<OpenBarrierRequest> opened = [];
  final List<BarrierConfigUpdate> saved = [];

  @override
  Future<List<Barrier>> list() async {
    listCalls += 1;
    if (listError case final error?) throw error;
    return List.of(barriers);
  }

  @override
  Future<BarrierCommand> openManually(OpenBarrierRequest request) async {
    if (openError case final error?) throw error;
    opened.add(request);
    return fakeBarrierCommand(status: BarrierCommandStatus.queued);
  }

  @override
  Future<BarrierCommand> command(String id) async {
    if (commandError case final error?) throw error;
    final index = commandCalls < pollStatuses.length
        ? commandCalls
        : pollStatuses.length - 1;
    commandCalls += 1;
    return fakeBarrierCommand(status: pollStatuses[index]);
  }

  @override
  Future<List<BarrierCommand>> history({int? deviceId}) async =>
      List.of(historyItems);

  @override
  Future<Barrier> saveConfig(BarrierConfigUpdate update) async {
    if (saveError case final error?) throw error;
    saved.add(update);
    return barriers.first;
  }
}
