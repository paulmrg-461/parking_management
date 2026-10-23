import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/lot/lot_context.dart';
import 'package:parking_management/core/lot/lot_session.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/lots/application/lots_cubit.dart';

import '../../../helpers/fake_key_value_store.dart';
import '../../../helpers/fake_lots_repository.dart';

void main() {
  late FakeLotsRepository repository;
  late FakeKeyValueStore store;
  late LotSession session;
  late LotContext context;
  late LotsCubit cubit;

  setUp(() {
    repository = FakeLotsRepository([sampleLot(), sampleLot(id: 2, code: 'N2', name: 'North')]);
    store = FakeKeyValueStore();
    session = LotSession();
    context = LotContext(store, session);
    cubit = LotsCubit(repository, context);
  });

  tearDown(() => cubit.close());

  test('Success: load exposes the memberships and picks a default lot', () async {
    await cubit.load();

    final state = cubit.state as LotsLoaded;
    expect(state.lots.length, 2);
    expect(state.canSwitch, isTrue);
    expect(state.activeId, 1);
    expect(session.activeLotId, 1);
  });

  test('Success: the last selected lot is restored', () async {
    await store.put(LotContext.box, 'active_lot_id', 2);

    await cubit.load();

    expect((cubit.state as LotsLoaded).activeId, 2);
    expect(session.activeLotId, 2);
  });

  test('Success: switching persists and applies the lot', () async {
    await cubit.load();

    await cubit.select(2);

    expect((cubit.state as LotsLoaded).activeId, 2);
    expect(session.activeLotId, 2);
    expect(store.get(LotContext.box, 'active_lot_id'), 2);
  });

  test('Failure: a stale persisted lot falls back to the first membership',
      () async {
    await store.put(LotContext.box, 'active_lot_id', 99);

    await cubit.load();

    expect((cubit.state as LotsLoaded).activeId, 1);
  });

  test('Failure: a rejected create keeps the list and reports it', () async {
    await cubit.load();
    repository.writeError = const ValidationFailure(
      'DuplicateLotCodeError',
      'DuplicateLotCodeError',
    );

    await cubit.create(code: 'N3', name: 'Third');

    final state = cubit.state as LotsLoaded;
    expect(state.lots.length, 2);
    expect((state.submission as SubmissionFailed).failure?.code,
        'DuplicateLotCodeError');
  });

  test('Security: only loaded memberships can become the active lot', () async {
    await cubit.select(2);

    expect(session.activeLotId, isNull);
    expect(cubit.state, isA<LotsInitial>());
  });
}
