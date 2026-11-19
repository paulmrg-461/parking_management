import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/state/submission.dart';
import 'package:parking_management/features/lpr/application/lpr_settings_cubit.dart';
import 'package:parking_management/features/lpr/domain/commands/lpr_settings_update.dart';
import 'package:parking_management/features/lpr/domain/entities/lpr_settings.dart';

import '../../../helpers/fake_lpr_repository.dart';

void main() {
  test('load emits the settings with cameras', () async {
    final cubit = LprSettingsCubit(FakeLprRepository());
    await cubit.load();
    final state = cubit.state as LprSettingsLoaded;
    expect(state.settings.cameras.single.name, 'Entrada');
    await cubit.close();
  });

  test('no cameras emits the call-to-action state', () async {
    final cubit = LprSettingsCubit(
      FakeLprRepository()..settingsValue = fakeLprSettings(cameras: []),
    );
    await cubit.load();
    expect(cubit.state, isA<LprSettingsNoCameras>());
    await cubit.close();
  });

  test('a load failure keeps the retry path', () async {
    final cubit = LprSettingsCubit(
      FakeLprRepository()..settingsError = const NetworkFailure('offline'),
    );
    await cubit.load();
    expect(cubit.state, isA<LprSettingsFailure>());
    await cubit.close();
  });

  test('save stores and reports the result', () async {
    final repository = FakeLprRepository();
    final cubit = LprSettingsCubit(repository);
    await cubit.load();
    await cubit.save(const LprSettingsUpdate(mode: LprMode.auto, actingUserId: 7));
    expect(repository.saved.single.mode, LprMode.auto);
    final state = cubit.state as LprSettingsLoaded;
    expect(state.submission, isA<SubmissionSucceeded>());
    expect(state.settings.mode, LprMode.auto);
    await cubit.close();
  });

  test('a save failure keeps the current settings', () async {
    final repository = FakeLprRepository()
      ..saveError = const ValidationFailure('bad');
    final cubit = LprSettingsCubit(repository);
    await cubit.load();
    await cubit.save(const LprSettingsUpdate(minVotes: 4));
    final state = cubit.state as LprSettingsLoaded;
    expect(state.submission, isA<SubmissionFailed>());
    expect(state.settings.minVotes, 3);
    await cubit.close();
  });

  test('save before the first load is ignored', () async {
    final repository = FakeLprRepository();
    final cubit = LprSettingsCubit(repository);
    await cubit.save(const LprSettingsUpdate(minVotes: 4));
    expect(repository.saved, isEmpty);
    await cubit.close();
  });

  test('a direction write failure keeps the list and reports it', () async {
    final repository = FakeLprRepository()
      ..directionError = const ValidationFailure('bad');
    final cubit = LprSettingsCubit(repository);
    await cubit.load();
    await cubit.setDirection(3, 'exit');
    final state = cubit.state as LprSettingsLoaded;
    expect(state.submission, isA<SubmissionFailed>());
    expect(state.settings.cameras.single.direction, 'entry');
    await cubit.close();
  });

  test('setDirection refreshes the camera list', () async {
    final repository = FakeLprRepository();
    final cubit = LprSettingsCubit(repository);
    await cubit.load();
    await cubit.setDirection(3, 'exit');
    expect(repository.directions.single, (3, 'exit'));
    final state = cubit.state as LprSettingsLoaded;
    expect(state.settings.cameras.single.direction, 'exit');
    await cubit.close();
  });
}
