import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/devices/domain/entities/lot_device.dart';
import 'package:parking_management/features/devices/domain/repositories/device_repository.dart';

LotDevice sampleDevice({
  int id = 1,
  String name = 'Entrada',
  DeviceStatus status = DeviceStatus.online,
  String keyPrefix = '3fa94c0b12de',
  String? apiKey,
}) => LotDevice(
  id: id,
  kind: DeviceKind.camera,
  name: name,
  keyPrefix: keyPrefix,
  status: status,
  apiKey: apiKey,
);

class FakeDeviceRepository implements DeviceRepository {
  FakeDeviceRepository({List<LotDevice>? devices})
    : devices = devices ?? [sampleDevice()];

  List<LotDevice> devices;
  int offlineMinutes = 5;
  Failure? loadError;
  Failure? writeError;
  int registerCalls = 0;
  int rotateCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Future<DeviceList> list() async {
    final error = loadError;
    if (error != null) throw error;
    return DeviceList(offlineMinutes: offlineMinutes, devices: devices);
  }

  @override
  Future<LotDevice> register({
    required DeviceKind kind,
    required String name,
  }) async {
    registerCalls++;
    final error = writeError;
    if (error != null) throw error;
    final device = sampleDevice(id: 2, name: name, apiKey: 'pkd_key');
    devices = [...devices, device];
    return device;
  }

  @override
  Future<LotDevice> rotate(int id) async {
    rotateCalls++;
    return sampleDevice(id: id, apiKey: 'pkd_rotated');
  }

  @override
  Future<LotDevice> update(
    int id, {
    String? name,
    bool? enabled,
    int? ratePerMinute,
  }) async {
    updateCalls++;
    final error = writeError;
    if (error != null) throw error;
    if (name != null) {
      devices = [
        for (final device in devices)
          if (device.id == id)
            sampleDevice(
              id: id,
              name: name,
              status: device.status,
              keyPrefix: device.keyPrefix,
            )
          else
            device,
      ];
    }
    return sampleDevice(id: id, name: name ?? 'Entrada');
  }

  @override
  Future<void> delete(int id) async {
    deleteCalls++;
    devices = [for (final device in devices) if (device.id != id) device];
  }

  @override
  Future<List<DeviceEvent>> events(int? deviceId) async => const [
    DeviceEvent(id: 1, event: 'registered'),
  ];

  @override
  Future<int> setOfflineMinutes(int minutes) async {
    offlineMinutes = minutes;
    return minutes;
  }
}
