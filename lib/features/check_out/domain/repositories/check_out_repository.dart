import '../../../../core/pagination/paged_result.dart';
import '../entities/check_out_receipt.dart';
import '../entities/open_session.dart';

abstract class CheckOutRepository {
  /// One page of open sessions (`limit`/`offset`, `X-Total-Count`).
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
  });

  /// Closes [sessionId] using the backend clock. Offline, the attempt time
  /// is queued as `client_exit_time` and replayed by
  /// `CheckOutMutationReplayer`.
  Future<CheckOutReceipt> checkOut(int sessionId);
}
