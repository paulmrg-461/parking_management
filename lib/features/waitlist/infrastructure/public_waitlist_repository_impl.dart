import '../../public_booking/domain/entities/public_booking.dart';
import '../domain/entities/public_waitlist.dart';
import '../domain/repositories/public_waitlist_repository.dart';
import 'public_waitlist_remote_data_source.dart';

class PublicWaitlistRepositoryImpl implements PublicWaitlistRepository {
  PublicWaitlistRepositoryImpl(this._remote);

  final PublicWaitlistRemoteDataSource _remote;

  @override
  Future<PublicWaitlistInfo?> info(int lotId) => _remote.info(lotId);

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
  }) => _remote.join(
    lotId: lotId,
    plate: plate,
    categoryId: categoryId,
    waitUntil: waitUntil,
    holdMinutes: holdMinutes,
    phone: phone,
    name: name,
    captchaToken: captchaToken,
  );

  @override
  Future<PublicWaitlistEntry?> lookup({
    required int lotId,
    required int entryId,
    required String phone,
  }) => _remote.lookup(lotId: lotId, entryId: entryId, phone: phone);

  @override
  Future<PublicReservation> claim({
    required int lotId,
    required int entryId,
    required String phone,
  }) => _remote.claim(lotId: lotId, entryId: entryId, phone: phone);

  @override
  Future<void> leave({
    required int lotId,
    required int entryId,
    required String phone,
  }) => _remote.leave(lotId: lotId, entryId: entryId, phone: phone);
}
