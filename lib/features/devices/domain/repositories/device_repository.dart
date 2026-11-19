import '../entities/lot_device.dart';

class DeviceList {
  const DeviceList({this.offlineMinutes = 5, this.devices = const []});

  final int offlineMinutes;
  final List<LotDevice> devices;

  factory DeviceList.fromJson(Map<String, dynamic> json) => DeviceList(
    offlineMinutes: (json['offline_minutes'] as num?)?.toInt() ?? 5,
    devices: [
      for (final item in (json['devices'] as List? ?? const []))
        if (item is Map) LotDevice.fromJson(Map<String, dynamic>.from(item)),
    ],
  );
}

abstract class DeviceRepository {
  Future<DeviceList> list();

  Future<LotDevice> register({required DeviceKind kind, required String name});

  Future<LotDevice> rotate(int id);

  Future<LotDevice> update(
    int id, {
    String? name,
    bool? enabled,
    int? ratePerMinute,
  });

  Future<void> delete(int id);

  Future<List<DeviceEvent>> events(int? deviceId);

  Future<int> setOfflineMinutes(int minutes);
}
