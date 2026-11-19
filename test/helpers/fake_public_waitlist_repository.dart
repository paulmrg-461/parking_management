import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/public_booking/domain/entities/public_booking.dart';
import 'package:parking_management/features/waitlist/domain/entities/public_waitlist.dart';
import 'package:parking_management/features/waitlist/domain/entities/waitlist_entry.dart';
import 'package:parking_management/features/waitlist/domain/repositories/public_waitlist_repository.dart';

/// Anonymous repository double for the public card tests.
class FakePublicWaitlistRepository implements PublicWaitlistRepository {
  PublicWaitlistInfo? infoValue = const PublicWaitlistInfo(
    enabled: true,
    claimMinutes: 15,
    notifyChannel: WaitlistChannel.screen,
  );
  PublicWaitlistEntry entry = PublicWaitlistEntry(
    id: 7,
    plate: 'ABC123',
    categoryId: 2,
    categoryName: 'car',
    status: WaitlistStatus.waiting,
    position: 1,
    waitUntil: DateTime.utc(2026, 1, 1, 15),
    holdMinutes: 60,
    claimMinutes: 15,
    notifyChannel: WaitlistChannel.screen,
  );
  Failure? infoError;
  Failure? joinError;
  Failure? lookupError;
  Failure? claimError;
  Failure? leaveError;
  Failure? pollError;
  int lookups = 0;
  final List<Map<String, Object?>> joins = [];
  PublicReservation? claimedReservation;

  @override
  Future<PublicWaitlistInfo?> info(int lotId) async {
    if (infoError != null) {
      throw infoError!;
    }
    return infoValue;
  }

  @override
  Future<PublicWaitlistEntry> join({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime waitUntil,
    required int holdMinutes,
    required String phone,
    required String name,
    String? captchaToken,
  }) async {
    joins.add({
      'lot_id': lotId,
      'plate': plate,
      'category_id': categoryId,
      'phone': phone,
      'name': name,
      'token': captchaToken,
    });
    if (joinError != null) {
      throw joinError!;
    }
    return entry;
  }

  @override
  Future<PublicWaitlistEntry?> lookup({
    required int lotId,
    required int entryId,
    required String phone,
  }) async {
    lookups += 1;
    if (lookupError != null) {
      throw lookupError!;
    }
    return entry;
  }

  @override
  Future<PublicReservation> claim({
    required int lotId,
    required int entryId,
    required String phone,
  }) async {
    if (claimError != null) {
      throw claimError!;
    }
    return claimedReservation ??
        PublicReservation(
          id: 900,
          plate: entry.plate,
          categoryName: entry.categoryName,
          reservedUntil: DateTime.utc(2026, 1, 1, 16),
        );
  }

  @override
  Future<void> leave({
    required int lotId,
    required int entryId,
    required String phone,
  }) async {
    if (leaveError != null) {
      throw leaveError!;
    }
  }
}
