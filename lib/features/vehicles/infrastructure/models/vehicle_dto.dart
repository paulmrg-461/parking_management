import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/vehicle.dart';

part 'vehicle_dto.g.dart';

@JsonSerializable()
class VehicleDto {
  const VehicleDto({
    this.id,
    required this.plate,
    required this.categoryId,
    this.color,
    this.brand,
  });

  factory VehicleDto.fromJson(Map<String, dynamic> json) =>
      _$VehicleDtoFromJson(json);

  final int? id;
  final String plate;

  @JsonKey(name: 'category_id')
  final int categoryId;

  final String? color;
  final String? brand;

  Map<String, dynamic> toJson() => _$VehicleDtoToJson(this);

  Vehicle toDomain() => Vehicle(
        id: id,
        plate: plate,
        categoryId: categoryId,
        color: color,
        brand: brand,
      );
}
