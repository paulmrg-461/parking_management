import '../domain/entities/session_record.dart';
import '../domain/repositories/record_repository.dart';
import 'record_remote_data_source.dart';

class RecordRepositoryImpl implements RecordRepository {
  RecordRepositoryImpl(this._remote);

  final RecordRemoteDataSource _remote;

  @override
  Future<SessionRecordPage> list({
    String plate = '',
    int offset = 0,
    int limit = 50,
  }) => _remote.list(plate: plate, offset: offset, limit: limit);
}
