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

  /// Active public hold for [reservationId] + [phone], or null when nothing
  /// matches (the customer mistyped, or the hold expired or was used).
  Future<PublicReservation?> lookup({
    required int lotId,
    required int reservationId,
    required String phone,
  });

  /// Creates the hold. [captchaToken] is the proof from the captcha widget
  /// when the page rendered one; with it the booking goes through the
  /// verifying Edge Function instead of the anonymous RPC.
  Future<PublicReservation> reserve({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime until,
    required String phone,
    required String name,
    String? captchaToken,
  });
}
