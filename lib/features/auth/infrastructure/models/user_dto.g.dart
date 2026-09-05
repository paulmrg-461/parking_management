// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDto _$UserDtoFromJson(Map<String, dynamic> json) => UserDto(
  id: (json['id'] as num?)?.toInt(),
  username: json['username'] as String,
  displayName: json['display_name'] as String,
  role: json['role'] as String,
  isActive: json['is_active'] as bool? ?? true,
);

Map<String, dynamic> _$UserDtoToJson(UserDto instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'display_name': instance.displayName,
  'role': instance.role,
  'is_active': instance.isActive,
};
