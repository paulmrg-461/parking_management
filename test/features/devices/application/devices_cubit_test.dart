import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/devices/application/devices_cubit.dart';
import 'package:parking_management/features/devices/domain/entities/lot_device.dart';

import '../../../helpers/fake_device_repository.dart';

void main() {
  DevicesLoaded loaded(DevicesCubit cubit) => cubit.state as DevicesLoaded;

  test('load emits the device list', () async {
    final cubit = DevicesCubit(FakeDeviceRepository());
    await cubit.load();
    expect(loaded(cubit).list.devices, hasLength(1));
    await cubit.close();
  });

  test('load failure emits failure', () async {
    final cubit = DevicesCubit(
      FakeDeviceRepository()..loadError = const NetworkFailure('offline'),
    );
    await cubit.load();
    expect(cubit.state, isA<DevicesFailure>());
    await cubit.close();
  });

  test('register returns the device with its key', () async {
    final repository = FakeDeviceRepository();
    final cubit = DevicesCubit(repository);
    await cubit.load();
    final device = await cubit.register(DeviceKind.barrier, 'Nueva');
    expect(device?.apiKey, 'pkd_key');
    expect(loaded(cubit).list.devices, hasLength(2));
    await cubit.close();
  });

  test('toggle calls update', () async {
    final repository = FakeDeviceRepository();
    final cubit = DevicesCubit(repository);
    await cubit.load();
    await cubit.toggle(loaded(cubit).list.devices.single);
    expect(repository.updateCalls, 1);
    await cubit.close();
  });

  test('delete removes the device', () async {
    final repository = FakeDeviceRepository();
    final cubit = DevicesCubit(repository);
    await cubit.load();
    await cubit.delete(1);
    expect(loaded(cubit).list.devices, isEmpty);
    await cubit.close();
  });

  test('rotate and rename refresh the list', () async {
    final repository = FakeDeviceRepository();
    final cubit = DevicesCubit(repository);
    await cubit.load();
    final rotated = await cubit.rotate(1);
    expect(rotated?.apiKey, 'pkd_rotated');
    await cubit.rename(loaded(cubit).list.devices.single, 'Nueva');
    expect(repository.updateCalls, 1);
    await cubit.close();
  });

  test('setOfflineMinutes saves the threshold', () async {
    final repository = FakeDeviceRepository();
    final cubit = DevicesCubit(repository);
    await cubit.load();
    await cubit.setOfflineMinutes(12);
    expect(loaded(cubit).list.offlineMinutes, 12);
    await cubit.close();
  });

  test('a register failure keeps the list and reports it', () async {
    final repository = FakeDeviceRepository()
      ..writeError = const ValidationFailure(
        'DeviceNameTakenError',
        'DeviceNameTakenError',
      );
    final cubit = DevicesCubit(repository);
    await cubit.load();
    expect(await cubit.register(DeviceKind.camera, 'X'), isNull);
    expect(loaded(cubit).list.devices, hasLength(1));
    await cubit.close();
  });

  test('events delegates to the repository', () async {
    final cubit = DevicesCubit(FakeDeviceRepository());
    await cubit.load();
    expect((await cubit.events(1)).single.event, 'registered');
    await cubit.close();
  });

  test('write failures keep the list and report them', () async {
    final repository = FakeDeviceRepository()
      ..writeError = const ValidationFailure('DeviceNotFoundError', 'DeviceNotFoundError');
    final cubit = DevicesCubit(repository);
    await cubit.load();
    final device = loaded(cubit).list.devices.single;
    await cubit.rotate(device.id);
    await cubit.toggle(device);
    await cubit.rename(device, 'X');
    expect(loaded(cubit).list.devices, hasLength(1));
    await cubit.close();
  });
}
