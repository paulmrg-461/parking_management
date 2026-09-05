import '../entities/check_out_receipt.dart';
import '../entities/open_session.dart';

abstract class CheckOutRepository {
  Future<List<OpenSession>> listOpenSessions();

  Future<CheckOutReceipt> checkOut(int sessionId);
}
