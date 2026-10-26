import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/category.dart';

part 'category_dto.g.dart';

@JsonSerializable()
class CategoryDto {
  const CategoryDto({this.id, required this.name, this.capacity = 0});

  factory CategoryDto.fromJson(Map<String, dynamic> json) =>
      _$CategoryDtoFromJson(json);

  final int? id;
  final String name;
  final int capacity;

  Map<String, dynamic> toJson() => _$CategoryDtoToJson(this);

  Category toDomain() => Category(id: id, name: name, capacity: capacity);
}
