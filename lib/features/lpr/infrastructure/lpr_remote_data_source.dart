import 'dart:typed_data';

import '../../../core/network/supabase_error_mapper.dart';
import '../../check_in/domain/entities/parking_session.dart';
import '../../check_in/infrastructure/models/parking_session_dto.dart';
import '../domain/commands/confirm_lpr_entry.dart';
import '../domain/entities/lpr_event.dart';
import '../domain/repositories/lpr_repository.dart';

typedef LprRpc = Future<dynamic> Function(
  String name,
  Map<String, dynamic> params,
);

typedef LprDownload = Future<Uint8List> Function(String path);

abstract class LprRemoteDataSource {
  Future<List<LprEvent>> listEvents({String status});

  Future<ParkingSessionDto> confirm({
    required int eventId,
    String? plate,
    int? categoryId,
  });

  Future<void> dismiss(int eventId, {String? note});

  Future<Uint8List> snapshot(String path);
}

class SupabaseLprRemoteDataSource implements LprRemoteDataSource {
  SupabaseLprRemoteDataSource(this._rpc, this._download);

  final LprRpc _rpc;
  final LprDownload _download;

  @override
  Future<List<LprEvent>> listEvents({String status = 'pending'}) async {
    try {
      final data = await _rpc('list_lpr_events', {'p_status': status});
      return [
        for (final item in (data as List? ?? const []))
          if (item is Map) LprEvent.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<ParkingSessionDto> confirm({
    required int eventId,
    String? plate,
    int? categoryId,
  }) async {
    try {
      final data = await _rpc('confirm_lpr_entry', {
        'p_event_id': eventId,
        'p_plate': plate,
        'p_category_id': categoryId,
      });
      return ParkingSessionDto.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> dismiss(int eventId, {String? note}) async {
    try {
      await _rpc('dismiss_lpr_event', {
        'p_event_id': eventId,
        'p_note': note,
      });
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<Uint8List> snapshot(String path) async {
    try {
      return await _download(path);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}

class LprRepositoryImpl implements LprRepository {
  LprRepositoryImpl(this._remote);

  final LprRemoteDataSource _remote;

  @override
  Future<List<LprEvent>> listEvents({String status = 'pending'}) =>
      _remote.listEvents(status: status);

  @override
  Future<ParkingSession> confirmEntry(ConfirmLprEntry command) async {
    final dto = await _remote.confirm(
      eventId: command.eventId,
      plate: command.plate,
      categoryId: command.categoryId,
    );
    return dto.toDomain();
  }

  @override
  Future<void> dismiss(int eventId, {String? note}) =>
      _remote.dismiss(eventId, note: note);

  @override
  Future<Uint8List> snapshot(String path) => _remote.snapshot(path);
}
