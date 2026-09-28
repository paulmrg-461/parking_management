import '../../../core/error/failure.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/repositories/check_out_repository.dart';

/// Use case: closes a parking session. Sessions still waiting to sync
/// (client-side negative ids) have no server id yet and are rejected here,
/// so they can never be sent or queued as a check-out.
class CheckOutVehicle {
  CheckOutVehicle(this._repository);

  final CheckOutRepository _repository;

  Future<CheckOutReceipt> call(int sessionId) async {
    if (sessionId <= 0) {
      throw const ValidationFailure(
        'This check-in is still waiting to sync; try again once online',
        ClientFailureCodes.pendingSyncCheckOut,
      );
    }
    return _repository.checkOut(sessionId);
  }
}
