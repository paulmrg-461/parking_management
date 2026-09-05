import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/tariff.dart';

part 'tariff_dto.g.dart';

@JsonSerializable()
class TariffDto {
  const TariffDto({
    this.id,
    required this.categoryId,
    required this.type,
    required this.amount,
    this.startTime,
    this.endTime,
    this.active = true,
  });

  factory TariffDto.fromJson(Map<String, dynamic> json) =>
      _$TariffDtoFromJson(json);

  final int? id;

  @JsonKey(name: 'category_id')
  final int categoryId;

  final String type;
  final int amount;

  @JsonKey(name: 'start_time')
  final String? startTime;

  @JsonKey(name: 'end_time')
  final String? endTime;

  final bool active;

  Map<String, dynamic> toJson() => _$TariffDtoToJson(this);

  Tariff toDomain() => Tariff(
        id: id,
        categoryId: categoryId,
        type: _parseType(type),
        amount: amount,
        startTime: startTime,
        endTime: endTime,
        active: active,
      );

  static TariffType _parseType(String value) {
    return TariffType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => TariffType.hourly,
    );
  }
}
