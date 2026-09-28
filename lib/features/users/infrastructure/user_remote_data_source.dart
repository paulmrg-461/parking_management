import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/infrastructure/models/user_dto.dart';

abstract class UserRemoteDataSource {
  Future<List<User>> list();

  Future<User> create(Map<String, dynamic> payload);

  Future<User> update(int id, Map<String, dynamic> payload);
}

class DioUserRemoteDataSource implements UserRemoteDataSource {
  DioUserRemoteDataSource(this._dio);

  final Dio _dio;

  static const _path = '/api/users';

  @override
  Future<List<User>> list() => _guard(() async {
    final response = await _dio.get<List<dynamic>>(_path);
    return [
      for (final item in response.data ?? const <dynamic>[])
        UserDto.fromJson(item as Map<String, dynamic>).toDomain(),
    ];
  });

  @override
  Future<User> create(Map<String, dynamic> payload) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _path,
      data: payload,
    );
    return UserDto.fromJson(response.data!).toDomain();
  });

  @override
  Future<User> update(int id, Map<String, dynamic> payload) => _guard(() async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '$_path/$id',
      data: payload,
    );
    return UserDto.fromJson(response.data!).toDomain();
  });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
