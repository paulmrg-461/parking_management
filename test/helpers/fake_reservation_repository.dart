import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/reservations/domain/entities/reservation.dart';
import 'package:parking_management/features/reservations/domain/repositories/reservation_repository.dart';

class FakeReservationRepository implements ReservationRepository {
  FakeReservationRepository([List<Reservation> reservations = const []])
    : reservations = List.of(reservations);

  List<Reservation> reservations;
  Failure? listError;
  Failure? writeError;
  String? createdPlate;
  int? createdCategoryId;
  DateTime? createdUntil;
  int? cancelledId;

  @override
  Future<List<Reservation>> listActive() async =>
      listError == null ? List.of(reservations) : throw listError!;

  @override
  Future<Reservation> create({
    required String plate,
    required int categoryId,
    required DateTime until,
    String? notes,
  }) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    createdPlate = plate;
    createdCategoryId = categoryId;
    createdUntil = until;
    final reservation = Reservation(
      id: reservations.length + 1,
      plate: plate,
      categoryId: categoryId,
      reservedUntil: until,
      notes: notes,
    );
    reservations = [...reservations, reservation];
    return reservation;
  }

  @override
  Future<void> cancel(int id) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    cancelledId = id;
    reservations = reservations.where((r) => r.id != id).toList();
  }
}

Reservation sampleReservation({
  int id = 1,
  String plate = 'ABC123',
  String categoryName = 'car',
  String? notes,
  DateTime? reservedUntil,
}) => Reservation(
  id: id,
  plate: plate,
  categoryId: 2,
  categoryName: categoryName,
  reservedUntil: reservedUntil ?? DateTime.now().add(const Duration(hours: 2)),
  notes: notes,
);
