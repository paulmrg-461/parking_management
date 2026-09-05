import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/user.dart';

part 'user_dto.g.dart';

@JsonSerializable()
class UserDto {
  const UserDto({
    this.id,
    required this.username,
    required this.displayName,
    required this.role,
    this.isActive = true,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);

  final int? id;
  final String username;

  @JsonKey(name: 'display_name')
  final String displayName;

  final String role;

  @JsonKey(name: 'is_active')
  final bool isActive;

  Map<String, dynamic> toJson() => _$UserDtoToJson(this);

  User toDomain() => User(
        id: id,
        username: username,
        displayName: displayName,
        role: role == 'admin' ? UserRole.admin : UserRole.operator,
        isActive: isActive,
      );
}
