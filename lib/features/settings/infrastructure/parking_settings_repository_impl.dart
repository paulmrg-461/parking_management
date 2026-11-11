import 'dart:convert';
import 'dart:typed_data';

import '../../../core/error/failure.dart';
import '../../../core/lot/lot_session.dart';
import '../../../core/sync/pending_mutation.dart';
import '../../../core/sync/sync_outbox.dart';
import '../domain/entities/parking_settings.dart';
import '../domain/repositories/parking_settings_repository.dart';
import 'parking_settings_local_data_source.dart';
import 'parking_settings_remote_data_source.dart';

class ParkingSettingsRepositoryImpl implements ParkingSettingsRepository {
  ParkingSettingsRepositoryImpl(
    this._remote,
    this._local,
    this._outbox,
    this._lots,
  );

  final ParkingSettingsRemoteDataSource _remote;
  final ParkingSettingsLocalDataSource _local;
  final SyncOutbox _outbox;
  final LotSession _lots;

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
    final cached = await _local.read();
    final base = cached ?? ParkingSettings.defaults();
    // Only the fields the operator actually changed are written: a text edit
    // must not clobber a logo someone else uploaded meanwhile.
    final fields = _changedFields(base, settings);
    if (fields.isEmpty) {
      return base;
    }
    final activeLot = _lots.activeLotId;
    if (cached != null) {
      await _guardPendingConflict();
    }
    try {
      final saved = await _remote.patch(
        fields,
        lotId: activeLot,
        baseVersion: base.version > 0 ? base.version : null,
      );
      await _local.upsert(saved);
      return saved;
    } on VersionConflictFailure catch (failure) {
      await _parkConflict(fields, activeLot, cached, failure);
      rethrow;
    } on NetworkFailure {
      // Optimistic: the form is usable offline and the queue replays later.
      await _local.upsert(settings);
      await _outbox.enqueue(
        PendingMutation(
          entityType: MutationEntity.settings,
          operation: MutationOperation.update,
          entityId: null,
          // The replay must hit this lot even if the operator switches sites.
          payloadJson: jsonEncode({...fields, 'lot_id': ?activeLot}),
          enqueuedAt: DateTime.now(),
          baseVersion: base.version > 0 ? base.version : null,
          baseSnapshotJson: cached == null
              ? null
              : jsonEncode(_snapshot(cached)),
        ),
      );
      return settings;
    }
  }

  /// Payload keys whose value differs between [base] and [edited].
  Map<String, dynamic> _changedFields(
    ParkingSettings base,
    ParkingSettings edited,
  ) {
    final before = base.toPayload();
    return {
      for (final entry in edited.toPayload().entries)
        if (before[entry.key] != entry.value) entry.key: entry.value,
    };
  }

  Future<void> _guardPendingConflict() async {
    final conflicts = await _outbox.listConflicts();
    if (conflicts.any(
      (entry) => entry.value.entityType == MutationEntity.settings,
    )) {
      throw const ValidationFailure(
        'Conflict pending',
        ClientFailureCodes.conflictPending,
      );
    }
  }

  Future<void> _parkConflict(
    Map<String, dynamic> fields,
    int? lotId,
    ParkingSettings? cached,
    VersionConflictFailure failure,
  ) async {
    final entry = PendingMutation(
      entityType: MutationEntity.settings,
      operation: MutationOperation.update,
      entityId: null,
      payloadJson: jsonEncode({...fields, 'lot_id': ?lotId}),
      enqueuedAt: DateTime.now(),
      baseVersion: cached?.version,
      baseSnapshotJson: cached == null ? null : jsonEncode(_snapshot(cached)),
    );
    await _outbox.enqueue(
      entry.asConflict(
        kind: failure.serverRow == null ? 'deleted' : 'edited',
        serverRow: failure.serverRow,
      ),
    );
  }

  /// The cached row as the server sees it, so a three-way merge can tell
  /// which side changed a field.
  Map<String, dynamic> _snapshot(ParkingSettings settings) => {
    ...settings.toPayload(),
    'version': settings.version,
  };

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
  Future<String> resetLegalPolicy() => _remote.resetLegalPolicy();

  @override
  Future<ParkingSettings> uploadCover(Uint8List bytes) async {
    final saved = await _remote.uploadCover(bytes);
    await _local.upsert(saved);
    return saved;
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
