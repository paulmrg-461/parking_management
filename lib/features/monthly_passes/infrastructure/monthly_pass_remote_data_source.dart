import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../domain/entities/monthly_pass.dart';
import 'models/monthly_pass_dto.dart';

abstract class MonthlyPassRemoteDataSource {
  Future<List<MonthlyPass>> list(String token, {int? vehicleId});

  Future<MonthlyPass> create(String token, Map<String, dynamic> payload);

  Future<MonthlyPass> update(String token, int id, Map<String, dynamic> payload);

  Future<void> delete(String token, int id);
}

class DioMonthlyPassRemoteDataSource implements MonthlyPassRemoteDataSource {
  DioMonthlyPassRemoteDataSource(this._dio);

  final Dio _dio;

  static const _path = '/api/monthly-passes';

  @override
  Future<List<MonthlyPass>> list(String token, {int? vehicleId}) async {
    try {
      final response = await _dio.get(
        _path,
        queryParameters: vehicleId != null ? {'vehicle_id': vehicleId} : null,
        options: Options(headers: _auth(token)),
      );
      final data = response.data as List<dynamic>;
      return data
          .map((item) =>
              MonthlyPassDto.fromJson(item as Map<String, dynamic>).toDomain())
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<MonthlyPass> create(String token, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        _path,
        data: payload,
        options: Options(headers: _auth(token)),
      );
      return MonthlyPassDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<MonthlyPass> update(
    String token,
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.patch(
        '$_path/$id',
        data: payload,
        options: Options(headers: _auth(token)),
      );
      return MonthlyPassDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<void> delete(String token, int id) async {
    try {
      await _dio.delete('$_path/$id', options: Options(headers: _auth(token)));
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Map<String, String> _auth(String token) =>
      {'Authorization': 'Bearer $token'};
}
