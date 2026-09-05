import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../domain/entities/vehicle.dart';
import 'models/vehicle_dto.dart';

abstract class VehicleRemoteDataSource {
  Future<List<Vehicle>> list(String token, {String? plate});

  Future<Vehicle> create(String token, Map<String, dynamic> payload);

  Future<Vehicle> update(String token, int id, Map<String, dynamic> payload);

  Future<void> delete(String token, int id);
}

class DioVehicleRemoteDataSource implements VehicleRemoteDataSource {
  DioVehicleRemoteDataSource(this._dio);

  final Dio _dio;

  static const _path = '/api/vehicles';

  @override
  Future<List<Vehicle>> list(String token, {String? plate}) async {
    try {
      final response = await _dio.get(
        _path,
        queryParameters: plate != null ? {'plate': plate} : null,
        options: Options(headers: _auth(token)),
      );
      final data = response.data as List<dynamic>;
      return data
          .map((item) => VehicleDto.fromJson(item as Map<String, dynamic>).toDomain())
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<Vehicle> create(String token, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        _path,
        data: payload,
        options: Options(headers: _auth(token)),
      );
      return VehicleDto.fromJson(response.data as Map<String, dynamic>).toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<Vehicle> update(String token, int id, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.patch(
        '$_path/$id',
        data: payload,
        options: Options(headers: _auth(token)),
      );
      return VehicleDto.fromJson(response.data as Map<String, dynamic>).toDomain();
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
