import '../../../public_booking/domain/entities/public_booking.dart';
import '../entities/public_waitlist.dart';

/// Anonymous surface of the waitlist. Online only: nothing is queued.
abstract class PublicWaitlistRepository {
  Future<PublicWaitlistInfo?> info(int lotId);

  Future<PublicWaitlistEntry> join({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime waitUntil,
    required int holdMinutes,
    required String phone,
    required String name,
    String? captchaToken,
  });

  Future<PublicWaitlistEntry?> lookup({
    required int lotId,
    required int entryId,
    required String phone,
  });

  Future<PublicReservation> claim({
    required int lotId,
    required int entryId,
    required String phone,
  });

  Future<void> leave({
    required int lotId,
    required int entryId,
    required String phone,
  });
}
