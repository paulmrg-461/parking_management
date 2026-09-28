import 'package:dio/dio.dart';

class DioClient {
  DioClient(String baseUrl, {List<Interceptor> interceptors = const []})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ) {
    _dio.interceptors.addAll(interceptors);
  }

  final Dio _dio;

  Dio get dio => _dio;
}
