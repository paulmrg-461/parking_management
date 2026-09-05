import 'package:dio/dio.dart';

import '../error/failure.dart';

Failure mapDioError(DioException error) {
  switch (error.response?.statusCode) {
    case 401:
      return const AuthenticationFailure('Invalid credentials');
    case 403:
      return const AuthenticationFailure('Forbidden');
    case 404:
      return const ValidationFailure('Not found');
    default:
      return const NetworkFailure('Unable to reach the server');
  }
}
