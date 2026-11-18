import '../entities/assistant_progress.dart';
import '../entities/assistant_status.dart';
import '../entities/assistant_turn.dart';

abstract class ReportAssistantRepository {
  Future<AssistantStatus> status();

  Stream<AssistantEvent> ask(
    AssistantQuestion question,
    List<AssistantTurn> history,
  );
}
