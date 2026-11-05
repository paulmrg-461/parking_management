import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/vehicles/infrastructure/models/vehicle_dto.dart';

void main() {
  test('Success: owner name and phone map from the database columns', () {
    final vehicle = VehicleDto.fromJson(const {
      'id': 7,
      'plate': 'ABC123',
      'category_id': 2,
      'owner_name': 'Paul Realpe',
      'owner_phone': '+57 300 111 2233',
    }).toDomain();

    expect(vehicle.ownerName, 'Paul Realpe');
    expect(vehicle.ownerPhone, '+57 300 111 2233');
  });

  test('Empty: owner fields are optional and stay null', () {
    final vehicle = VehicleDto.fromJson(const {
      'id': 7,
      'plate': 'ABC123',
      'category_id': 2,
    }).toDomain();

    expect(vehicle.ownerName, isNull);
    expect(vehicle.ownerPhone, isNull);
  });
}
