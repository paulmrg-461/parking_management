import 'dart:convert';
import 'dart:typed_data';

import '../../../core/error/failure.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/sync_outbox.dart';
import '../domain/entities/parking_settings.dart';
import '../domain/repositories/parking_settings_repository.dart';
import 'parking_settings_local_data_source.dart';
import 'parking_settings_remote_data_source.dart';

class ParkingSettingsRepositoryImpl implements ParkingSettingsRepository {
  ParkingSettingsRepositoryImpl(this._remote, this._local, this._outbox);

  final ParkingSettingsRemoteDataSource _remote;
  final ParkingSettingsLocalDataSource _local;
  final SyncOutbox _outbox;

  @override
  Future<ParkingSettings> load() async {
    try {
      final settings = await _remote.fetch();
      await _local.upsert(settings);
      return settings;
    } on NetworkFailure {
      return await _local.read() ?? ParkingSettings.defaults();
    }
  }

  @override
  Future<ParkingSettings?> loadCached() => _local.read();

  @override
  Future<ParkingSettings> save(ParkingSettings settings) async {
    try {
      final saved = await _remote.patch(settings.toPayload());
      await _local.upsert(saved);
      return saved;
    } on NetworkFailure {
      // Optimistic: the form is usable offline and the queue replays later.
      await _local.upsert(settings);
      await _outbox.enqueue(
        PendingMutation(
          entityType: MutationEntity.settings,
          operation: MutationOperation.update,
          entityId: null,
          payloadJson: jsonEncode(settings.toPayload()),
          enqueuedAt: DateTime.now(),
        ),
      );
      return settings;
    }
  }

  @override
  Future<Uint8List?> loadLogo(int version) async {
    if (version == 0) {
      return null;
    }
    final cached = await _local.readLogo(version);
    if (cached != null) {
      return cached;
    }
    try {
      final bytes = await _remote.fetchLogo();
      await _local.putLogo(version, bytes);
      return bytes;
    } on NetworkFailure {
      return null;
    }
  }

  @override
  Future<ParkingSettings> uploadLogo(Uint8List bytes) async {
    // Connectivity is required by design: logo bytes are never queued, so a
    // failure here propagates and the cached logo stays untouched.
    final updated = await _remote.uploadLogo(bytes);
    await _local.upsert(updated);
    await _local.putLogo(updated.logoVersion, bytes);
    return updated;
  }
}
