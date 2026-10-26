import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/dio_error_mapper.dart';
import '../domain/entities/parking_settings.dart';
import 'models/parking_settings_dto.dart';

abstract class ParkingSettingsRemoteDataSource {
  Future<ParkingSettings> fetch();

  Future<ParkingSettings> patch(Map<String, dynamic> fields);

  Future<ParkingSettings> uploadLogo(Uint8List bytes);

  Future<Uint8List> fetchLogo();
}

class DioParkingSettingsRemoteDataSource
    implements ParkingSettingsRemoteDataSource {
  DioParkingSettingsRemoteDataSource(this._dio);

  final Dio _dio;

  static const _path = '/api/settings';

  @override
  Future<ParkingSettings> fetch() async {
    try {
      final response = await _dio.get(_path);
      return _toDomain(response.data);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<ParkingSettings> patch(Map<String, dynamic> fields) async {
    try {
      final response = await _dio.patch(_path, data: fields);
      return _toDomain(response.data);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<ParkingSettings> uploadLogo(Uint8List bytes) async {
    try {
      final response = await _dio.post(
        '$_path/logo',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: _filename(bytes)),
        }),
      );
      return _toDomain(response.data);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<Uint8List> fetchLogo() async {
    try {
      final response = await _dio.get<Uint8List>(
        '$_path/logo',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? (throw const NetworkFailure('Logo unavailable'));
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  ParkingSettings _toDomain(Object? data) =>
      ParkingSettingsDto.fromJson(data as Map<String, dynamic>).toDomain();

  /// The server sniffs magic bytes (the name is ignored); matching it keeps
  /// multipart metadata honest for logs and proxies.
  String _filename(Uint8List bytes) =>
      bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8
          ? 'logo.jpg'
          : 'logo.png';
}
