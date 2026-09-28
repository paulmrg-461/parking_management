import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';
import 'package:parking_management/features/tariffs/domain/entities/tariff.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_local_data_source.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_mutation_replayer.dart';
import 'package:parking_management/features/tariffs/infrastructure/tariff_remote_data_source.dart';

class _FakeRemote implements TariffRemoteDataSource {
  _FakeRemote([this.error]);

  final Failure? error;
  Map<String, dynamic>? updatePayload;
  int? deletedId;

  @override
  Future<Tariff> update(int id, Map<String, dynamic> payload) async {
    if (error != null) {
      throw error!;
    }
    updatePayload = payload;
    return Tariff(id: id, categoryId: 1, type: TariffType.hourly, amount: 2000);
  }

  @override
  Future<void> delete(int id) async => deletedId = id;

  @override
  Future<Tariff> create(Map<String, dynamic> payload) async =>
      throw UnimplementedError();

  @override
  Future<List<Tariff>> list() async => const [];
}

class _FakeLocal implements TariffLocalDataSource {
  final List<Tariff> upserted = [];

  @override
  Future<void> upsert(Tariff tariff) async => upserted.add(tariff);

  @override
  Future<void> cacheAll(List<Tariff> tariffs) async {}

  @override
  Future<List<Tariff>> readAll() async => const [];

  @override
  Future<void> remove(int id) async {}
}

PendingMutation _mutation(MutationOperation op, String? payload) =>
    PendingMutation(
      entityType: MutationEntity.tariff,
      operation: op,
      entityId: 3,
      payloadJson: payload,
      enqueuedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  test('Success: update replays the patch and refreshes the cache', () async {
    final remote = _FakeRemote();
    final local = _FakeLocal();

    await TariffMutationReplayer(remote, local)
        .replay(_mutation(MutationOperation.update, '{"amount":2000}'));

    expect(remote.updatePayload, {'amount': 2000});
    expect(local.upserted.single.amount, 2000);
  });

  test('Success: delete replays the delete', () async {
    final remote = _FakeRemote();

    await TariffMutationReplayer(remote, _FakeLocal())
        .replay(_mutation(MutationOperation.delete, null));

    expect(remote.deletedId, 3);
  });

  test('Failure: a 409 propagates so the outbox can dead-letter it', () async {
    await expectLater(
      TariffMutationReplayer(
        _FakeRemote(const ValidationFailure('Conflict')),
        _FakeLocal(),
      ).replay(_mutation(MutationOperation.update, '{"amount":2000}')),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
