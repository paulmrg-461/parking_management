import '../entities/client_error_report.dart';
import '../entities/whatsapp_message.dart';
import '../entities/diagnostics_snapshot.dart';

abstract class DiagnosticsRepository {
  Future<DiagnosticsSnapshot> snapshot();

  Future<List<ClientErrorReport>> clientErrors({
    int limit = 50,
    int days = 7,
  });

  Future<List<WhatsappMessage>> whatsappMessages({
    int limit = 50,
    int days = 7,
  });
}
