import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/check_in/domain/entities/parking_session.dart';
import 'package:parking_management/features/lpr/application/lpr_inbox_cubit.dart';
import 'package:parking_management/features/lpr/domain/commands/confirm_lpr_entry.dart';

import '../../../helpers/fake_lpr_repository.dart';

void main() {
  test('load emits the pending events', () async {
    final cubit = LprInboxCubit(FakeLprRepository());
    await cubit.load();
    final state = cubit.state as LprInboxLoaded;
    expect(state.events.single.plate, 'ABC123');
    await cubit.close();
  });

  test('an empty inbox emits the empty state', () async {
    final cubit = LprInboxCubit(FakeLprRepository()..events = []);
    await cubit.load();
    expect(cubit.state, isA<LprInboxEmpty>());
    await cubit.close();
  });

  test('a load failure keeps the retry path', () async {
    final cubit = LprInboxCubit(
      FakeLprRepository()..listError = const NetworkFailure('offline'),
    );
    await cubit.load();
    expect(cubit.state, isA<LprInboxFailure>());
    await cubit.close();
  });

  test('confirm removes the card and reports the session', () async {
    final repository = FakeLprRepository();
    final cubit = LprInboxCubit(repository);
    await cubit.load();
    await cubit.confirm(const ConfirmLprEntry(eventId: 1, plate: 'XYZ987'));
    expect(repository.confirmed.single.plate, 'XYZ987');
    expect(cubit.state, isA<LprInboxEmpty>());
    final submission = (cubit.state as LprInboxEmpty).submission;
    expect(submission, isA<SubmissionSucceeded<ParkingSession>>());
    await cubit.close();
  });

  test('a confirm failure keeps the card and reports it', () async {
    final cubit = LprInboxCubit(
      FakeLprRepository()..confirmError = const ValidationFailure('bad'),
    );
    await cubit.load();
    await cubit.confirm(const ConfirmLprEntry(eventId: 1));
    final state = cubit.state as LprInboxLoaded;
    expect(state.events, hasLength(1));
    expect(state.submission, isA<SubmissionFailed>());
    await cubit.close();
  });

  test('a double tap confirms once', () async {
    final repository = FakeLprRepository();
    final cubit = LprInboxCubit(repository);
    await cubit.load();
    final first = cubit.confirm(const ConfirmLprEntry(eventId: 1));
    final second = cubit.confirm(const ConfirmLprEntry(eventId: 1));
    await Future.wait([first, second]);
    expect(repository.confirmed, hasLength(1));
    await cubit.close();
  });

  test('polling stops when the cubit closes', () async {
    final cubit = LprInboxCubit(FakeLprRepository());
    await cubit.load();
    cubit.startPolling();
    expect(cubit.isPolling, isTrue);
    await cubit.close();
    expect(cubit.isPolling, isFalse);
  });
}
