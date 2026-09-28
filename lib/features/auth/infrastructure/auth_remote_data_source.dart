import 'package:dio/dio.dart';

import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/dio_error_mapper.dart';
import '../domain/entities/auth_session.dart';
import 'models/user_dto.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSession> login(String username, String pin);
}

class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  DioAuthRemoteDataSource(this._dio);

  final Dio _dio;

  static const _authPath = '/api/auth/login';

  @override
  Future<AuthSession> login(String username, String pin) async {
    try {
      final response = await _dio.post(
        _authPath,
        data: {'username': username, 'pin': pin},
        options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
      );
      return _parseSession(response.data as Map<String, dynamic>);
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
}
