import '../entities/public_booking.dart';

/// Anonymous customer booking (no account): availability + one hold.
abstract class PublicBookingRepository {
  Future<PublicBookingAvailability?> availability(int lotId);

  Future<void> cancel({
    required int lotId,
    required int reservationId,
    required String plate,
    required String phone,
  });

  Future<PublicReservation> reserve({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime until,
    required String phone,
    required String name,
  });
}
