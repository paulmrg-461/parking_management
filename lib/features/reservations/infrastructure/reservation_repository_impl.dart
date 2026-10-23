import '../domain/entities/reservation.dart';
import '../domain/repositories/reservation_repository.dart';
import 'reservation_remote_data_source.dart';

class ReservationRepositoryImpl implements ReservationRepository {
  ReservationRepositoryImpl(this._remote);

  final ReservationRemoteDataSource _remote;

  @override
  Future<List<Reservation>> listActive() => _remote.listActive();

  @override
  Future<Reservation> create({
    required String plate,
    required int categoryId,
    required DateTime until,
    String? notes,
  }) => _remote.create(
    plate: plate,
    categoryId: categoryId,
    until: until,
    notes: notes,
  );

  @override
  Future<void> cancel(int id) => _remote.cancel(id);
}
