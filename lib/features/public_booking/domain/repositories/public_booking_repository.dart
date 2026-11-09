import '../entities/public_booking.dart';

/// Anonymous customer booking (no account): availability + one hold.
abstract class PublicBookingRepository {
  Future<PublicBookingAvailability?> availability(int lotId);

  Future<PublicReservation> reserve({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime until,
    required String phone,
    String? name,
  });
}
