import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/entities/occupancy_snapshot.dart';
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
  });

  List<OpenSession> sessions;
  Failure? listError;
  final int capacity;
  final List<CategoryOccupancySnapshot> categories;
  TodaySummary today;
  Failure? todayError;
  int occupancyCalls = 0;
  int listCalls = 0;

  @override
  Future<TodaySummary> todaySummary() async {
    final error = todayError;
    if (error != null) {
      throw error;
    }
    return today;
  }

  @override
  Future<OccupancySnapshot> occupancy() async {
    occupancyCalls++;
    final error = listError;
    if (error != null) {
      throw error;
    }
    return OccupancySnapshot(
      totalOpen: sessions.length,
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
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    String paymentMethod = 'cash',
    int discountAmount = 0,
    String? discountReason,
    bool lostTicket = false,
    String? lostTicketReason,
  }) => throw UnimplementedError();
}
