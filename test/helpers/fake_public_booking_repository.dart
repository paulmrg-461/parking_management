import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/features/public_booking/domain/entities/public_booking.dart';
import 'package:parking_management/features/public_booking/domain/repositories/public_booking_repository.dart';

class FakePublicBookingRepository implements PublicBookingRepository {
  PublicBookingAvailability? availabilityToReturn;
  Failure? availabilityError;
  Failure? reserveError;
  PublicReservation? reservationToReturn;
  int availabilityCalls = 0;
  int reserveCalls = 0;
  int? lastLotId;
  String? lastPlate;
  int? lastCategoryId;
  DateTime? lastUntil;
  String? lastPhone;
  String? lastName;

  @override
  Future<PublicBookingAvailability?> availability(int lotId) async {
    availabilityCalls++;
    lastLotId = lotId;
    final error = availabilityError;
    if (error != null) {
      throw error;
    }
    return availabilityToReturn;
  }

  @override
  Future<PublicReservation> reserve({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime until,
    required String phone,
    String? name,
  }) async {
    reserveCalls++;
    lastLotId = lotId;
    lastPlate = plate;
    lastCategoryId = categoryId;
    lastUntil = until;
    lastPhone = phone;
    lastName = name;
    final error = reserveError;
    if (error != null) {
      throw error;
    }
    return reservationToReturn ??
        PublicReservation(
          id: 12,
          plate: plate,
          categoryName: 'car',
          reservedUntil: until,
          lotName: 'Parqueadero',
          address: 'Calle 1',
          phone: '3001112233',
          whatsapp: '3001112233',
        );
  }
}

PublicBookingAvailability sampleAvailability({
  int available = 4,
  bool full = false,
  bool unlimited = false,
}) => PublicBookingAvailability(
  lotId: 1,
  lotName: 'Parqueadero Central',
  address: 'Calle 1 #2-3',
  schedule: '24 horas',
  phone: '3001112233',
  whatsapp: '3001112233',
  categories: [
    PublicCategoryAvailability(
      id: 2,
      name: 'car',
      group: 'car',
      categoryCapacity: 10,
      groupCapacity: 10,
      occupied: 6,
      reserved: 0,
      available: unlimited ? null : (full ? 0 : available),
    ),
    PublicCategoryAvailability(
      id: 3,
      name: 'moto',
      group: 'moto',
      categoryCapacity: 5,
      groupCapacity: 5,
      occupied: 1,
      reserved: 0,
      available: 4,
    ),
  ],
);
