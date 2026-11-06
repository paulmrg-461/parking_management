import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_preview.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/dashboard_trend.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/entities/capacity_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/occupancy_snapshot.dart';
import 'package:parking_management/features/check_out/domain/entities/slot_board.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';

/// Open sessions held in memory; [listError] makes the list fail.
class FakeCheckOutRepository implements CheckOutRepository {
  FakeCheckOutRepository({
    this.sessions = const [],
    this.listError,
    this.capacity = 0,
    this.categories = const [],
    this.today = TodaySummary.empty,
    this.todayError,
    this.trend = DashboardTrend.empty,
    this.trendError,
  });

  List<OpenSession> sessions;
  Failure? listError;
  final int capacity;
  final List<CategoryOccupancySnapshot> categories;
  TodaySummary today;
  Failure? todayError;
  DashboardTrend trend;
  Failure? trendError;
  int trendCalls = 0;
  int occupancyCalls = 0;
  int listCalls = 0;

  /// When set, `occupancy()` waits for it (to interleave concurrent loads).
  Future<void>? occupancyGate;

  @override
  Future<TodaySummary> todaySummary() async {
    final error = todayError;
    if (error != null) {
      throw error;
    }
    return today;
  }

  @override
  Future<DashboardTrend> dashboardTrend({int days = 7}) async {
    trendCalls++;
    final error = trendError;
    if (error != null) {
      throw error;
    }
    return trend;
  }

  CapacitySnapshot capacityToReturn = CapacitySnapshot.empty;
  Failure? capacityError;

  SlotBoard slotBoardToReturn = SlotBoard.empty;

  @override
  Future<SlotBoard> slotBoard() async => slotBoardToReturn;

  @override
  Future<CapacitySnapshot> capacitySnapshot() async {
    final error = capacityError;
    if (error != null) {
      throw error;
    }
    return capacityToReturn;
  }

  @override
  Future<OccupancySnapshot> occupancy() async {
    occupancyCalls++;
    final gate = occupancyGate;
    final total = sessions.length;
    await gate;
    final error = listError;
    if (error != null) {
      throw error;
    }
    return OccupancySnapshot(
      totalOpen: total,
      totalCapacity: capacity,
      byCategory: categories,
    );
  }

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
    String? plate,
  }) async {
    listCalls++;
    final error = listError;
    if (error != null) {
      throw error;
    }
    return PagedResult(
      sessions.skip(offset).take(limit).toList(),
      total: sessions.length,
    );
  }

  @override
  Future<CheckOutPreview> preview(int sessionId) async =>
      CheckOutPreview(sessionId: sessionId, amount: 5000);

  @override
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    String paymentMethod = 'cash',
    int discountAmount = 0,
    String? discountReason,
    bool lostTicket = false,
    String? lostTicketReason,
    String? cardType,
    int? cashReceived,
    String? plate,
    DateTime? entryTime,
  }) => throw UnimplementedError();
}
