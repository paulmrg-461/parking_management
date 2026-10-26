import '../domain/entities/client_error_report.dart';
import '../domain/entities/whatsapp_message.dart';
import '../domain/entities/diagnostics_snapshot.dart';
import '../domain/repositories/diagnostics_repository.dart';
import 'diagnostics_remote_data_source.dart';

class DiagnosticsRepositoryImpl implements DiagnosticsRepository {
  DiagnosticsRepositoryImpl(this._remote);

  final DiagnosticsRemoteDataSource _remote;

  @override
  Future<DiagnosticsSnapshot> snapshot() => _remote.snapshot();

  @override
  Future<List<ClientErrorReport>> clientErrors({
    int limit = 50,
    int days = 7,
  }) => _remote.clientErrors(limit: limit, days: days);

  @override
  Future<List<WhatsappMessage>> whatsappMessages({
    int limit = 50,
    int days = 7,
  }) => _remote.whatsappMessages(limit: limit, days: days);
}
