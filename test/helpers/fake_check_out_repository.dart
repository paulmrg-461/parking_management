import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/pagination/paged_result.dart';
import 'package:parking_management/features/check_out/domain/entities/check_out_receipt.dart';
import 'package:parking_management/features/check_out/domain/entities/open_session.dart';
import 'package:parking_management/features/check_out/domain/repositories/check_out_repository.dart';

/// Open sessions held in memory; [listError] makes the list fail.
class FakeCheckOutRepository implements CheckOutRepository {
  FakeCheckOutRepository({this.sessions = const [], this.listError});

  List<OpenSession> sessions;
  Failure? listError;
  int listCalls = 0;

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    int offset = 0,
    int limit = defaultPageSize,
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
  Future<CheckOutReceipt> checkOut(int sessionId) =>
      throw UnimplementedError();
}
