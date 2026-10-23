import '../entities/reservation.dart';

abstract class ReservationRepository {
  /// Active, not-yet-expired holds, soonest first.
  Future<List<Reservation>> listActive();

  Future<Reservation> create({
    required String plate,
    required int categoryId,
    required DateTime until,
    String? notes,
  });

  Future<void> cancel(int id);
}
