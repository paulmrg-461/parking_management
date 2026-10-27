import '../../../../core/pagination/paged_result.dart';
import '../entities/capacity_snapshot.dart';
import '../entities/check_out_preview.dart';
import '../entities/check_out_receipt.dart';
import '../entities/occupancy_snapshot.dart';
import '../entities/open_session.dart';
import '../entities/today_summary.dart';

abstract class CheckOutRepository {
  /// One page of open sessions (`limit`/`offset`, `X-Total-Count`).
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
    String? plate,
  });

  /// Closes [sessionId] using the backend clock. Offline, the attempt time
  /// is queued as `client_exit_time` and replayed by
  /// `CheckOutMutationReplayer`.
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    String paymentMethod = 'cash',
    int discountAmount = 0,
    String? discountReason,
    bool lostTicket = false,
    String? lostTicketReason,
  });

  /// Fare the customer would pay right now (no side effects).
  Future<CheckOutPreview> preview(int sessionId);

  /// Space configuration and what is inside (home dashboard).
  Future<CapacitySnapshot> capacitySnapshot();

  /// Open sessions + capacity per category (any signed-in user).
  Future<OccupancySnapshot> occupancy();

  /// Today's revenue/entries/exits for the active site (home dashboard).
  Future<TodaySummary> todaySummary();
}
