import 'dart:convert';
import 'dart:io';

import '../../features/categories/domain/repositories/category_repository.dart';
import '../../features/check_in/domain/repositories/check_in_repository.dart';
import '../../features/check_out/domain/repositories/check_out_repository.dart';
import '../../features/tariffs/domain/commands/update_tariff_command.dart';
import '../../features/tariffs/domain/entities/tariff.dart';
import '../../features/tariffs/domain/repositories/tariff_repository.dart';
import '../../features/vehicles/domain/commands/update_vehicle_command.dart';
import '../../features/vehicles/domain/repositories/vehicle_repository.dart';
import '../error/failure.dart';
import '../network/connectivity_service.dart';
import 'pending_mutation.dart';
import 'pending_photo_storage.dart';
import 'sync_outbox.dart';

/// Replays queued mutations (see `SyncOutbox`) against the backend once
/// connectivity is restored: `update`/`delete` for the three simple
/// reference-data repositories, plus `create` (check-in) and `close`
/// (check-out).
///
/// Replays go through each repository's own public create/update/delete/
/// checkOut method (not a separate "raw remote" path) — those methods
/// already succeed via remote when actually online, so no duplicate replay
/// logic is needed here.
class SyncService {
  SyncService(
    this._outbox,
    this._connectivity,
    this._vehicles,
    this._tariffs,
    this._categories,
    this._checkIns,
    this._checkOuts,
    this._pendingPhotos,
  );

  final SyncOutbox _outbox;
  final ConnectivityService _connectivity;
  final VehicleRepository _vehicles;
  final TariffRepository _tariffs;
  final CategoryRepository _categories;
  final CheckInRepository _checkIns;
  final CheckOutRepository _checkOuts;
  final PendingPhotoStorage _pendingPhotos;

  /// Subscribes to connectivity changes and flushes the outbox whenever the
  /// device comes back online. Also flushes once eagerly in case
  /// connectivity is already up when the app starts.
  void start() {
    _connectivity.onConnectivityChanged.listen((online) {
      if (online) {
        flush();
      }
    });
    flush();
  }

  /// Attempts to replay every pending mutation. A mutation that still fails
  /// with a `NetworkFailure` (e.g. connectivity flapped) is left in the
  /// outbox and does NOT block the remaining entries — this is a deliberate
  /// trade-off (simple last-write-wins semantics over anything more
  /// sophisticated), documented in `design.md`.
  Future<void> flush() async {
    if (!await _connectivity.isOnline()) {
      return;
    }

    for (final entry in await _outbox.listPending()) {
      try {
        await _replay(entry.value);
        await _outbox.remove(entry.key);
      } on NetworkFailure {
        // Leave this entry queued and continue with the next one.
      }
    }
  }

  Future<void> _replay(PendingMutation mutation) {
    switch (mutation.entityType) {
      case 'vehicle':
        return _replayVehicle(mutation);
      case 'tariff':
        return _replayTariff(mutation);
      case 'category':
        return _replayCategory(mutation);
      case 'checkIn':
        return _replayCheckIn(mutation);
      case 'checkOut':
        return _replayCheckOut(mutation);
      default:
        return Future.value();
    }
  }

  Future<void> _replayVehicle(PendingMutation mutation) async {
    if (mutation.operation == 'delete') {
      await _vehicles.delete(mutation.entityId!);
      return;
    }
    final payload = _decode(mutation.payloadJson);
    await _vehicles.update(
      UpdateVehicleCommand(
        id: mutation.entityId!,
        categoryId: payload['category_id'] as int?,
        color: payload['color'] as String?,
        brand: payload['brand'] as String?,
      ),
    );
  }

  Future<void> _replayTariff(PendingMutation mutation) async {
    if (mutation.operation == 'delete') {
      await _tariffs.delete(mutation.entityId!);
      return;
    }
    final payload = _decode(mutation.payloadJson);
    await _tariffs.update(
      UpdateTariffCommand(
        id: mutation.entityId!,
        type: payload['type'] != null
            ? TariffType.values.byName(payload['type'] as String)
            : null,
        amount: payload['amount'] as int?,
        startTime: payload['start_time'] as String?,
        endTime: payload['end_time'] as String?,
        active: payload['active'] as bool?,
      ),
    );
  }

  Future<void> _replayCategory(PendingMutation mutation) async {
    if (mutation.operation == 'delete') {
      await _categories.delete(mutation.entityId!);
      return;
    }
    final payload = _decode(mutation.payloadJson);
    await _categories.update(mutation.entityId!, payload['name'] as String);
  }

  /// Rebuilds the `File` list from the persisted photo paths and re-submits
  /// the exact same create request that would have been sent online; on
  /// success, cleans up the persisted photo folder.
  Future<void> _replayCheckIn(PendingMutation mutation) async {
    final payload = _decode(mutation.payloadJson);
    final clientRef = payload['client_ref'] as String;
    final photoPaths = (payload['photo_paths'] as List<dynamic>).cast<String>();

    await _checkIns.createCheckIn(
      plate: payload['plate'] as String,
      photos: [for (final path in photoPaths) File(path)],
    );
    await _pendingPhotos.deleteFor(clientRef);
  }

  /// Passes the originally captured `client_exit_time` through unchanged —
  /// see `CheckOutRepositoryImpl` for why it must not be recaptured here.
  Future<void> _replayCheckOut(PendingMutation mutation) async {
    final payload = _decode(mutation.payloadJson);
    await _checkOuts.checkOut(
      mutation.entityId!,
      clientExitTime: DateTime.parse(payload['client_exit_time'] as String),
    );
  }

  Map<String, dynamic> _decode(String? payloadJson) =>
      jsonDecode(payloadJson!) as Map<String, dynamic>;
}
