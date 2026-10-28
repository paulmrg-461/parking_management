import '../entities/session_record.dart';

abstract class RecordRepository {
  /// Latest sessions, optionally filtered by plate (partial match).
  Future<SessionRecordPage> list({
    String plate = '',
    int offset = 0,
    int limit = 50,
  });
}
