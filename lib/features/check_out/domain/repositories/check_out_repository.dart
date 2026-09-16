import '../entities/check_out_receipt.dart';
import '../entities/open_session.dart';

abstract class CheckOutRepository {
  Future<List<OpenSession>> listOpenSessions();

  /// Closes [sessionId]. [clientExitTime] is only passed by
  /// `SyncService._replayCheckOut` (the original attempt time captured when
  /// this check-out was first queued offline); the online path omits it so
  /// the backend uses its own clock, unchanged.
  Future<CheckOutReceipt> checkOut(int sessionId, {DateTime? clientExitTime});
}
