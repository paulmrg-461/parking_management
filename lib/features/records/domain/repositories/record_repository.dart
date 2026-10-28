import '../entities/session_record.dart';

abstract class RecordRepository {
  /// Latest sessions, optionally filtered by plate (partial match) and by an
  /// inclusive business-date range.
  Future<SessionRecordPage> list({
    String plate = '',
    DateTime? from,
    DateTime? to,
    int offset = 0,
    int limit = 50,
  });
}
