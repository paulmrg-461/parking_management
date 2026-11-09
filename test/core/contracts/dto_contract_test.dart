import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/infrastructure/models/user_dto.dart';
import 'package:parking_management/features/categories/infrastructure/models/category_dto.dart';
import 'package:parking_management/features/check_in/infrastructure/models/parking_session_dto.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/lots/domain/entities/lot_member.dart';
import 'package:parking_management/features/lots/domain/entities/parking_lot.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass_payment.dart';
import 'package:parking_management/features/policies/domain/entities/lot_profile.dart';
import 'package:parking_management/features/check_out/domain/entities/lot_setup_status.dart';
import 'package:parking_management/features/evidence/domain/entities/session_evidence.dart';
import 'package:parking_management/features/reports/domain/entities/hourly_traffic.dart';
import 'package:parking_management/features/records/domain/entities/session_record.dart';
import 'package:parking_management/features/spots/domain/entities/spot_event.dart';
import 'package:parking_management/features/monthly_passes/infrastructure/models/monthly_pass_dto.dart';
import 'package:parking_management/features/vehicles/infrastructure/models/vehicle_dto.dart';

void main() {
  group('vehicle DTO', () {
    test('Success: maps snake_case columns and owner phone', () {
      final dto = VehicleDto.fromJson({
        'id': 7,
        'plate': 'ABC123',
        'category_id': 2,
        'color': 'Rojo',
        'brand': 'Mazda',
        'owner_phone': '3001112233',
      });

      final vehicle = dto.toDomain();
      expect(vehicle.id, 7);
      expect(vehicle.plate, 'ABC123');
      expect(vehicle.categoryId, 2);
      expect(vehicle.ownerPhone, '3001112233');
      expect(dto.toJson()['category_id'], 2);
    });

    test('Failure: optional columns may be absent', () {
      final dto = VehicleDto.fromJson({'plate': 'XYZ999', 'category_id': 1});

      expect(dto.toDomain().color, isNull);
      expect(dto.toDomain().ownerPhone, isNull);
    });
  });

  group('user DTO', () {
    test('Security: only the admin role is elevated', () {
      final admin = UserDto.fromJson({
        'username': 'ana',
        'display_name': 'Ana',
        'role': 'admin',
      }).toDomain();
      final unknown = UserDto.fromJson({
        'username': 'beto',
        'display_name': 'Beto',
        'role': 'superuser',
      }).toDomain();

      expect(admin.role.name, 'admin');
      expect(unknown.role.name, 'operator');
      expect(admin.isActive, isTrue);
    });
  });

  test('Success: category defaults capacity to zero', () {
    final category = CategoryDto.fromJson({'name': 'moto'}).toDomain();

    expect(category.name, 'moto');
    expect(category.capacity, 0);
  });

  test('Success: monthly pass parses dates and renewal defaults', () {
    final pass = MonthlyPassDto.fromJson({
      'id': 3,
      'vehicle_id': 1,
      'start_date': '2026-01-01T00:00:00Z',
      'end_date': '2026-01-31T00:00:00Z',
      'amount': 100000,
    }).toDomain();

    expect(pass.vehicleId, 1);
    expect(pass.startDate, DateTime.utc(2026, 1, 1));
    expect(pass.active, isTrue);
    expect(pass.autoRenew, isFalse);
    expect(pass.autoRenewPaymentMethod, 'cash');
  });

  test('Security: parking session status and flags map safely', () {
    final open = ParkingSessionDto.fromJson({
      'id': 1,
      'plate': 'ABC123',
      'status': 'open',
      'entry_time': '2026-11-05T10:00:00Z',
      'photo_count': 2,
    }).toDomain();
    final closed = ParkingSessionDto.fromJson({
      'id': 2,
      'plate': 'ABC123',
      'status': 'closed',
      'entry_time': '2026-11-05T10:00:00Z',
      'photo_count': 0,
    }).toDomain();

    expect(open.leftKeys, isFalse);
    expect(open.videoCount, 0);
    expect(open.status.name, 'open');
    expect(closed.status.name, 'closed');
  });

  test('Success: lot member grows from RPC JSON with sane defaults', () {
    final member = LotMember.fromJson({
      'user_id': 4,
      'username': 'ana',
      'display_name': 'Ana',
      'role': 'admin',
      'is_active': false,
    });

    expect(member.isAdmin, isTrue);
    expect(member.isActive, isFalse);
    expect(LotMember.fromJson({'user_id': 5}).role, 'operator');
  });

  group('domain JSON contracts', () {
    test('LotProfile parses the public profile safely', () {
      final profile = LotProfile.fromJson({
        'id': 1,
        'name': 'Central',
        'legal_policy': 'Texto',
      });

      expect(profile.id, 1);
      expect(profile.phone, '');
      expect(profile.legalPolicy, 'Texto');
    });

    test('MonthlyPassPayment exposes the pending state', () {
      final payment = MonthlyPassPayment.fromJson({
        'id': 9,
        'monthly_pass_id': 3,
        'vehicle_id': 1,
        'plate': 'ABC123',
        'start_date': '2026-01-01T00:00:00Z',
        'end_date': '2026-01-31T00:00:00Z',
        'amount': 80000,
        'status': 'pending',
        'due_date': '2026-02-01T00:00:00Z',
      });

      expect(payment.isPending, isTrue);
      expect(payment.paymentMethod, 'cash');
      expect(payment.amount, 80000);
    });

    test('TodaySummary defaults missing counters to zero', () {
      final today = TodaySummary.fromJson({'revenue': 5000, 'entries': 2});

      expect(today.revenue, 5000);
      expect(today.entries, 2);
      expect(today.exits, 0);
      expect(today.passRevenue, 0);
    });

    test('SessionRecord keeps open/closed timestamps and duration', () {
      final open = SessionRecord.fromJson({
        'id': 1,
        'plate': 'ABC123',
        'entry_time': '2026-11-05T10:00:00Z',
        'status': 'open',
        'duration_seconds': 3600,
      });
      final closed = SessionRecord.fromJson({
        'id': 2,
        'plate': 'ABC123',
        'entry_time': '2026-11-05T10:00:00Z',
        'exit_time': '2026-11-05T11:00:00Z',
        'status': 'closed',
        'amount_charged': 5000,
      });

      expect(open.isOpen, isTrue);
      expect(open.exitTime, isNull);
      expect(open.duration, const Duration(hours: 1));
      expect(closed.isOpen, isFalse);
      expect(closed.amountCharged, 5000);
    });

    test('ParkingLot applies defaults and copyWith keeps identity', () {
      final lot = ParkingLot.fromJson({'id': 2, 'name': 'Norte'});
      final edited = lot.copyWith(name: 'Norte 2', role: 'admin');

      expect(lot.code, '');
      expect(lot.timezone, 'America/Bogota');
      expect(edited.name, 'Norte 2');
      expect(edited.isLotAdmin, isTrue);
      expect(edited.id, lot.id);
    });

    test('SpotEvent keeps optional reason and actor', () {
      final event = SpotEvent.fromJson({
        'id': 3,
        'spot_id': 7,
        'spot_code': 'A1',
        'status': 'out_of_service',
        'active': false,
        'reason': 'fuga de aceite',
        'actor_name': 'Paul',
        'created_at': '2026-11-09T10:00:00Z',
      });

      expect(event.active, isFalse);
      expect(event.reason, 'fuga de aceite');
      expect(event.actorName, 'Paul');
      expect(event.spotId, 7);
      expect(event.createdAt.isUtc, isFalse);

      final bare = SpotEvent.fromJson({
        'id': 4,
        'spot_code': 'B2',
        'active': true,
      });
      expect(bare.reason, isNull);
      expect(bare.actorName, isNull);
      expect(bare.active, isTrue);
    });

    test('HourlyTraffic sorts its 24 buckets and picks the peak hour', () {
      final traffic = HourlyTraffic.fromJson({
        'timezone': 'America/Bogota',
        'hours': [
          for (var hour = 23; hour >= 0; hour--)
            {
              'hour': hour,
              'entries': hour == 8 ? 5 : 0,
              'exits': hour == 9 ? 3 : 0,
            },
        ],
      });

      expect(traffic.hours, hasLength(24));
      expect(traffic.hours.first.hour, 0);
      expect(traffic.hours.last.hour, 23);
      expect(traffic.peak!.hour, 8);
      expect(traffic.peakEntries, 5);
      expect(traffic.hasData, isTrue);
      expect(traffic.timezone, 'America/Bogota');

      expect(HourlyTraffic.fromJson(const {}).hasData, isFalse);
      expect(HourlyTraffic.empty.peak, isNull);
    });

    test('LotSetupStatus computes steps and completion from the flags', () {
      final ready = LotSetupStatus.fromJson({
        'categories': 2,
        'tariffs': 3,
        'car_capacity': 10,
        'moto_capacity': 5,
        'spots': 0,
        'has_address': true,
        'has_phone': true,
      });
      final mapOnly = LotSetupStatus.fromJson({
        'categories': 1,
        'tariffs': 1,
        'spots': 4,
        'has_address': true,
        'has_phone': false,
      });

      expect(ready.complete, isTrue);
      expect(ready.doneSteps, 4);
      expect(mapOnly.hasCapacity, isTrue);
      expect(mapOnly.hasIdentity, isFalse);
      expect(mapOnly.complete, isFalse);
      expect(mapOnly.doneSteps, 3);
      expect(LotSetupStatus.unknown.known, isFalse);
    });

    test('SessionEvidence maps kind, duration and an optional signed URL', () {
      final photo = SessionEvidence.fromJson({
        'id': 1,
        'file_path': 'abc/0.jpg',
        'kind': 'photo',
        'taken_at': '2026-11-09T10:00:00Z',
      });
      final video = SessionEvidence.fromJson({
        'id': 2,
        'file_path': 'abc/1.mp4',
        'kind': 'video',
        'duration_seconds': 42,
        'taken_at': '2026-11-09T10:05:00Z',
        'url': 'https://example.test/signed',
      });

      expect(photo.kind, EvidenceKind.photo);
      expect(photo.isVideo, isFalse);
      expect(photo.isAvailable, isFalse);
      expect(video.isVideo, isTrue);
      expect(video.isAvailable, isTrue);
      expect(video.durationSeconds, 42);
      expect(video.takenAt.isUtc, isFalse);
    });
  });
}
