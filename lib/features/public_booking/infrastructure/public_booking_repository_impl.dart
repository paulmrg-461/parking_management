import '../domain/entities/public_booking.dart';
import '../domain/repositories/public_booking_repository.dart';
import 'public_booking_remote_data_source.dart';

class PublicBookingRepositoryImpl implements PublicBookingRepository {
  PublicBookingRepositoryImpl(this._remote);

  final PublicBookingRemoteDataSource _remote;

  @override
  Future<PublicBookingAvailability?> availability(int lotId) =>
      _remote.availability(lotId);

  @override
  Future<PublicReservation> reserve({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime until,
    required String phone,
    required String name,
  }) => _remote.reserve(
    lotId: lotId,
    plate: plate,
    categoryId: categoryId,
    until: until,
    phone: phone,
    name: name,
  );
}
