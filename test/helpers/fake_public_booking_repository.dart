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
  Failure? cancelError;
  PublicReservation? lookupToReturn;
  Failure? lookupError;
  int lookupCalls = 0;
  int? lastLookupId;
  String? lastLookupPhone;
  int cancelCalls = 0;
  int? lastCancelId;
  String? lastCancelPlate;
  String? lastCancelPhone;
  int? lastLotId;
  String? lastPlate;
  int? lastCategoryId;
  DateTime? lastUntil;
  String? lastPhone;
  String? lastName;
  String? lastCaptchaToken;

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
  Future<PublicReservation?> lookup({
    required int lotId,
    required int reservationId,
    required String phone,
  }) async {
    lookupCalls++;
    lastLotId = lotId;
    lastLookupId = reservationId;
    lastLookupPhone = phone;
    final error = lookupError;
    if (error != null) {
      throw error;
    }
    return lookupToReturn;
  }

  @override
  Future<void> cancel({
    required int lotId,
    required int reservationId,
    required String plate,
    required String phone,
  }) async {
    cancelCalls++;
    lastLotId = lotId;
    lastCancelId = reservationId;
    lastCancelPlate = plate;
    lastCancelPhone = phone;
    final error = cancelError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<PublicReservation> reserve({
    required int lotId,
    required String plate,
    required int categoryId,
    required DateTime until,
    required String phone,
    required String name,
    String? captchaToken,
  }) async {
    reserveCalls++;
    lastCaptchaToken = captchaToken;
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
      hourlyAmount: 5000,
      available: unlimited ? null : (full ? 0 : available),
    ),
    const PublicCategoryAvailability(
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
