import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../domain/entities/parking_session.dart';
import 'models/parking_session_dto.dart';

abstract class CheckInRemoteDataSource {
  Future<ParkingSession> createCheckIn(
    String token, {
    required String plate,
    required List<File> photos,
  });

  Future<List<ParkingSession>> listOpenSessions(String token);
}

class DioCheckInRemoteDataSource implements CheckInRemoteDataSource {
  DioCheckInRemoteDataSource(this._dio);

  final Dio _dio;

  static const _path = '/api/check-ins';

  @override
  Future<ParkingSession> createCheckIn(
    String token, {
    required String plate,
    required List<File> photos,
  }) async {
    try {
      final formData = FormData.fromMap({
        'plate': plate,
        'photos': [
          for (final photo in photos) await MultipartFile.fromFile(photo.path),
        ],
      });
      final response = await _dio.post(
        _path,
        data: formData,
        options: Options(headers: _auth(token)),
      );
      return ParkingSessionDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<List<ParkingSession>> listOpenSessions(String token) async {
    try {
      final response = await _dio.get(
        _path,
        options: Options(headers: _auth(token)),
      );
      final data = response.data as List<dynamic>;
      return data
          .map((item) =>
              ParkingSessionDto.fromJson(item as Map<String, dynamic>).toDomain())
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token'};
}
