import '../domain/entities/assistant_progress.dart';
import '../domain/entities/assistant_status.dart';
import '../domain/entities/assistant_turn.dart';
import '../domain/repositories/report_assistant_repository.dart';
import 'report_assistant_remote_data_source.dart';

class ReportAssistantRepositoryImpl implements ReportAssistantRepository {
  ReportAssistantRepositoryImpl(this._remote);

  final ReportAssistantRemoteDataSource _remote;

  @override
  Future<AssistantStatus> status() => _remote.status();

  @override
  Stream<AssistantEvent> ask(
    AssistantQuestion question,
    List<AssistantTurn> history,
  ) => _remote.ask(question, history);
}
