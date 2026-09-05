import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/user.dart';
import 'models/user_dto.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSession> login(String username, String pin);

  Future<List<User>> listUsers(String token);

  Future<User> createUser(String token, Map<String, dynamic> payload);

  Future<User> updateUser(String token, int id, Map<String, dynamic> payload);
}

class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  DioAuthRemoteDataSource(this._dio);

  final Dio _dio;

  static const _authPath = '/api/auth/login';
  static const _usersPath = '/api/users';

  @override
  Future<AuthSession> login(String username, String pin) async {
    try {
      final response = await _dio.post(
        _authPath,
        data: {'username': username, 'pin': pin},
      );
      return _parseSession(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<List<User>> listUsers(String token) async {
    try {
      final response = await _dio.get(
        _usersPath,
        options: Options(headers: _authHeader(token)),
      );
      final data = response.data as List<dynamic>;
      return data
          .map((item) => UserDto.fromJson(item as Map<String, dynamic>).toDomain())
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<User> createUser(String token, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        _usersPath,
        data: payload,
        options: Options(headers: _authHeader(token)),
      );
      return UserDto.fromJson(response.data as Map<String, dynamic>).toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<User> updateUser(
    String token,
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.patch(
        '$_usersPath/$id',
        data: payload,
        options: Options(headers: _authHeader(token)),
      );
      return UserDto.fromJson(response.data as Map<String, dynamic>).toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  AuthSession _parseSession(Map<String, dynamic> data) {
    return AuthSession(
      user: UserDto.fromJson(data['user'] as Map<String, dynamic>).toDomain(),
      token: data['access_token'] as String,
    );
  }

  Map<String, String> _authHeader(String token) =>
      {'Authorization': 'Bearer $token'};
}
