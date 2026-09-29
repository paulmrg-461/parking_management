import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:parking_management/app/di/hive_registrar.g.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/features/settings/domain/entities/parking_settings.dart';
import 'package:parking_management/features/settings/infrastructure/parking_settings_local_data_source.dart';
import 'package:parking_management/features/settings/infrastructure/parking_settings_remote_data_source.dart';
import 'package:parking_management/features/settings/infrastructure/parking_settings_repository_impl.dart';

import '../../../helpers/fake_sync_outbox.dart';

const _remoteSettings = ParkingSettings(
  name: 'Parqueadero Central',
  address: 'Cra 7 # 12-34',
  phone: '+57 300 111 2233',
  logoVersion: 1,
);

const _logo = [1, 2, 3, 4];

class _FakeRemote implements ParkingSettingsRemoteDataSource {
  _FakeRemote({this.failWithNetwork = false});

  final bool failWithNetwork;
  ParkingSettings settings = _remoteSettings;
  Map<String, dynamic>? lastPatch;
  Uint8List? uploaded;

  void _ensureOnline() {
    if (failWithNetwork) {
      throw const NetworkFailure('offline');
    }
  }

  @override
  Future<ParkingSettings> fetch() async {
    _ensureOnline();
    return settings;
  }

  @override
  Future<ParkingSettings> patch(Map<String, dynamic> fields) async {
    _ensureOnline();
    lastPatch = fields;
    settings = settings.copyWith(
      name: fields['name'] as String? ?? settings.name,
      address: fields['address'] as String? ?? settings.address,
      schedule: fields['schedule'] as String? ?? settings.schedule,
      phone: fields['phone'] as String? ?? settings.phone,
      website: fields['website'] as String? ?? settings.website,
      whatsapp: fields['whatsapp'] as String? ?? settings.whatsapp,
    );
    return settings;
  }

  @override
  Future<ParkingSettings> uploadLogo(Uint8List bytes) async {
    _ensureOnline();
    uploaded = bytes;
    settings = settings.copyWith(logoVersion: settings.logoVersion + 1);
    return settings;
  }

  @override
  Future<Uint8List> fetchLogo() async {
    _ensureOnline();
    return Uint8List.fromList(_logo);
  }
}

void main() {
  late Directory tempDir;
  late FakeSyncOutbox outbox;

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_repo_test');
    Hive.init(tempDir.path);
    outbox = FakeSyncOutbox();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  ParkingSettingsRepositoryImpl repository(_FakeRemote remote) =>
      ParkingSettingsRepositoryImpl(
        remote,
        HiveParkingSettingsLocalDataSource(),
        outbox,
      );

  test('Success: load fetches remote settings and caches them', () async {
    final repo = repository(_FakeRemote());

    final loaded = await repo.load();

    expect(loaded.name, 'Parqueadero Central');
    expect((await repo.loadCached())?.name, 'Parqueadero Central');
  });

  test('Success: save online hits the backend and updates the cache', () async {
    final remote = _FakeRemote();
    final repo = repository(remote);
    const edited = ParkingSettings(name: 'Parqueadero Sur', address: 'Cll 1 # 2-3');

    final saved = await repo.save(edited);

    expect(saved.name, 'Parqueadero Sur');
    expect(remote.lastPatch?['name'], 'Parqueadero Sur');
    expect((await repo.loadCached())?.name, 'Parqueadero Sur');
    expect(outbox.enqueued, isEmpty);
  });

  test(
    'Failure: offline load falls back to the cache and then to defaults',
    () async {
      final local = HiveParkingSettingsLocalDataSource();
      await ParkingSettingsRepositoryImpl(
        _FakeRemote(),
        local,
        outbox,
      ).load();

      final offline = ParkingSettingsRepositoryImpl(
        _FakeRemote(failWithNetwork: true),
        local,
        outbox,
      );
      final fromCache = await offline.load();

      // Emptied cache: the caller still gets usable defaults, no error.
      final box = await Hive.openBox<ParkingSettings>('parking_settings');
      await box.clear();
      final defaults = await offline.load();

      expect(fromCache.name, 'Parqueadero Central');
      expect(defaults, ParkingSettings.defaults());
    },
  );

  test(
    'Failure: offline save applies optimistically and enqueues a mutation',
    () async {
      final local = HiveParkingSettingsLocalDataSource();
      await ParkingSettingsRepositoryImpl(
        _FakeRemote(),
        local,
        outbox,
      ).load();
      final offline = ParkingSettingsRepositoryImpl(
        _FakeRemote(failWithNetwork: true),
        local,
        outbox,
      );

      final result = await offline.save(
        const ParkingSettings(
          name: 'Parqueadero Central',
          address: 'Cra 7 # 12-34',
          phone: '+57 300 111 2233',
          logoVersion: 1,
        ).copyWith(name: 'Parqueadero Norte'),
      );

      expect(result.name, 'Parqueadero Norte');
      expect((await offline.loadCached())?.name, 'Parqueadero Norte');
      expect(outbox.enqueued, hasLength(1));
      final mutation = outbox.enqueued.single;
      expect(mutation.entityType, MutationEntity.settings);
      expect(mutation.operation, MutationOperation.update);
      expect(mutation.entityId, isNull);
      expect(mutation.decodePayload()['name'], 'Parqueadero Norte');
    },
  );

  test(
    'Failure: offline logo upload throws and leaves the cache untouched',
    () async {
      final local = HiveParkingSettingsLocalDataSource();
      final online = ParkingSettingsRepositoryImpl(
        _FakeRemote(),
        local,
        outbox,
      );
      await online.load();
      await online.uploadLogo(Uint8List.fromList(_logo));
      final cachedVersion = (await online.loadCached())!.logoVersion;

      final offline = ParkingSettingsRepositoryImpl(
        _FakeRemote(failWithNetwork: true),
        local,
        outbox,
      );

      await expectLater(
        offline.uploadLogo(Uint8List.fromList(const [9, 9, 9])),
        throwsA(isA<NetworkFailure>()),
      );
      expect((await offline.loadCached())?.logoVersion, cachedVersion);
      expect(await offline.loadLogo(cachedVersion), Uint8List.fromList(_logo));
      expect(outbox.enqueued, isEmpty);
    },
  );
}
