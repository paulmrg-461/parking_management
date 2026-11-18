import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/lot_device.dart';
import '../domain/repositories/device_repository.dart';

typedef DeviceRpc = Future<dynamic> Function(
  String name,
  Map<String, dynamic> params,
);

abstract class DeviceRemoteDataSource {
  Future<DeviceList> list();
  Future<LotDevice> register({required DeviceKind kind, required String name});
  Future<LotDevice> rotate(int id);
  Future<LotDevice> update(int id, {String? name, bool? enabled, int? ratePerMinute});
  Future<void> delete(int id);
  Future<List<DeviceEvent>> events(int? deviceId);
  Future<int> setOfflineMinutes(int minutes);
}

class SupabaseDeviceRemoteDataSource implements DeviceRemoteDataSource {
  SupabaseDeviceRemoteDataSource(this._rpc);

  final DeviceRpc _rpc;

  @override
  Future<DeviceList> list() async {
    try {
      final data = await _rpc('list_lot_devices', {});
      return DeviceList.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<LotDevice> register({
    required DeviceKind kind,
    required String name,
  }) async {
    try {
      final data = await _rpc('register_lot_device', {
        'p_kind': kind.wire,
        'p_name': name,
      });
      return LotDevice.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<LotDevice> rotate(int id) async {
    try {
      final data = await _rpc('rotate_lot_device_key', {'p_id': id});
      return LotDevice.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<LotDevice> update(
    int id, {
    String? name,
    bool? enabled,
    int? ratePerMinute,
  }) async {
    try {
      final data = await _rpc('update_lot_device', {
        'p_id': id,
        'p_name': name,
        'p_enabled': enabled,
        'p_rate_per_minute': ratePerMinute,
      });
      return LotDevice.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _rpc('delete_lot_device', {'p_id': id});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<DeviceEvent>> events(int? deviceId) async {
    try {
      final data = await _rpc('list_device_events', {
        'p_device_id': deviceId,
        'p_limit': 100,
      });
      return [
        for (final item in (data as List? ?? const []))
          if (item is Map) DeviceEvent.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<int> setOfflineMinutes(int minutes) async {
    try {
      final data = await _rpc('set_device_offline_minutes', {
        'p_minutes': minutes,
      });
      return ((data as Map)['offline_minutes'] as num?)?.toInt() ?? minutes;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}

class DeviceRepositoryImpl implements DeviceRepository {
  DeviceRepositoryImpl(this._remote);

  final DeviceRemoteDataSource _remote;

  @override
  Future<DeviceList> list() => _remote.list();

  @override
  Future<LotDevice> register({
    required DeviceKind kind,
    required String name,
  }) => _remote.register(kind: kind, name: name);

  @override
  Future<LotDevice> rotate(int id) => _remote.rotate(id);

  @override
  Future<LotDevice> update(
    int id, {
    String? name,
    bool? enabled,
    int? ratePerMinute,
  }) => _remote.update(id, name: name, enabled: enabled, ratePerMinute: ratePerMinute);

  @override
  Future<void> delete(int id) => _remote.delete(id);

  @override
  Future<List<DeviceEvent>> events(int? deviceId) => _remote.events(deviceId);

  @override
  Future<int> setOfflineMinutes(int minutes) =>
      _remote.setOfflineMinutes(minutes);
}
