import '../../../core/network/supabase_error_mapper.dart';
import '../domain/commands/barrier_config_update.dart';
import '../domain/commands/open_barrier_request.dart';
import '../domain/entities/barrier.dart';
import '../domain/entities/barrier_command.dart';
import '../domain/repositories/barrier_repository.dart';

typedef BarrierRpc = Future<dynamic> Function(
  String name,
  Map<String, dynamic> params,
);

abstract class BarrierRemoteDataSource {
  Future<List<Barrier>> list();

  Future<BarrierCommand> open(int deviceId, String reason);

  Future<BarrierCommand> command(String id);

  Future<List<BarrierCommand>> history(int? deviceId);

  Future<Barrier> saveConfig(BarrierConfigUpdate update);
}

class SupabaseBarrierRemoteDataSource implements BarrierRemoteDataSource {
  SupabaseBarrierRemoteDataSource(this._rpc);

  final BarrierRpc _rpc;

  @override
  Future<List<Barrier>> list() async {
    try {
      final data = await _rpc('list_barriers', {});
      return [
        for (final item in (data as List? ?? const []))
          if (item is Map) Barrier.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<BarrierCommand> open(int deviceId, String reason) async {
    try {
      final data = await _rpc('request_manual_barrier_open', {
        'p_device_id': deviceId,
        'p_reason': reason.trim(),
      });
      final id = (data as Map)['command_id'] as String;
      return await command(id);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<BarrierCommand> command(String id) async {
    try {
      final data = await _rpc('get_barrier_command', {'p_command_id': id});
      return BarrierCommand.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<List<BarrierCommand>> history(int? deviceId) async {
    try {
      final data = await _rpc('list_barrier_commands', {
        'p_device_id': deviceId,
        'p_limit': 100,
      });
      return [
        for (final item in (data as List? ?? const []))
          if (item is Map)
            BarrierCommand.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<Barrier> saveConfig(BarrierConfigUpdate update) async {
    try {
      await _rpc('set_barrier_config', {
        'p_device_id': update.deviceId,
        'p_direction': update.direction?.name,
        'p_camera_device_id': update.cameraDeviceId,
        'p_open_on_checkin': update.openOnCheckin,
        'p_open_on_paid_exit': update.openOnPaidExit,
        'p_open_for_pass_entry': update.openForPassEntry,
        'p_open_hold_ms': update.openHoldMs,
        'p_max_open_seconds': update.maxOpenSeconds,
        'p_post_clear_delay_ms': update.postClearDelayMs,
        'p_max_reversals': update.maxReversals,
        'p_command_ttl_seconds': update.commandTtlSeconds,
      });
      final barriers = await list();
      return barriers.firstWhere(
        (barrier) => barrier.deviceId == update.deviceId,
        orElse: () => throw const FormatException('barrier not found'),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}

class BarrierRepositoryImpl implements BarrierRepository {
  BarrierRepositoryImpl(this._remote);

  final BarrierRemoteDataSource _remote;

  @override
  Future<List<Barrier>> list() => _remote.list();

  @override
  Future<BarrierCommand> openManually(OpenBarrierRequest request) =>
      _remote.open(request.deviceId, request.reason);

  @override
  Future<BarrierCommand> command(String id) => _remote.command(id);

  @override
  Future<List<BarrierCommand>> history({int? deviceId}) =>
      _remote.history(deviceId);

  @override
  Future<Barrier> saveConfig(BarrierConfigUpdate update) =>
      _remote.saveConfig(update);
}
