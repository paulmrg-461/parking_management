import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/infrastructure/models/user_dto.dart';
import 'package:parking_management/features/categories/infrastructure/models/category_dto.dart';
import 'package:parking_management/features/check_in/infrastructure/models/parking_session_dto.dart';
import 'package:parking_management/features/check_out/domain/entities/today_summary.dart';
import 'package:parking_management/features/lots/domain/entities/lot_member.dart';
import 'package:parking_management/features/lots/domain/entities/parking_lot.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass_payment.dart';
import 'package:parking_management/features/policies/domain/entities/lot_profile.dart';
import 'package:parking_management/features/records/domain/entities/session_record.dart';
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
  });
}
