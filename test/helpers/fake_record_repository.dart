import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/records/domain/entities/session_record.dart';
import 'package:parking_management/features/records/domain/repositories/record_repository.dart';

class FakeRecordRepository implements RecordRepository {
  FakeRecordRepository([List<SessionRecord> records = const []])
    : records = List.of(records);

  List<SessionRecord> records;
  Failure? error;
  int listCalls = 0;
  String? lastPlate;
  int? lastOffset;

  @override
  Future<SessionRecordPage> list({
    String plate = '',
    int offset = 0,
    int limit = 50,
  }) async {
    listCalls++;
    lastPlate = plate;
    lastOffset = offset;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    final term = plate.trim().toUpperCase();
    final filtered = [
      for (final record in records)
        if (term.isEmpty || record.plate.toUpperCase().contains(term)) record,
    ];
    return SessionRecordPage(
      items: filtered.skip(offset).take(limit).toList(),
      total: filtered.length,
    );
  }
}

SessionRecord sampleRecord({
  int id = 1,
  String plate = 'ABC123',
  String status = 'closed',
  DateTime? entryTime,
  DateTime? exitTime,
  int amountCharged = 5000,
  int durationSeconds = 3600,
}) => SessionRecord(
  id: id,
  plate: plate,
  category: 'car',
  entryTime: entryTime ?? DateTime(2026, 10, 28, 8),
  exitTime: status == 'open'
      ? null
      : exitTime ?? DateTime(2026, 10, 28, 9),
  status: status,
  amountCharged: amountCharged,
  durationSeconds: durationSeconds,
);
