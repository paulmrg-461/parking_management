import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../../../core/network/pagination.dart';
import '../../../core/pagination/paged_result.dart';
import '../domain/entities/vehicle.dart';
import 'models/vehicle_dto.dart';

abstract class VehicleRemoteDataSource {
  Future<List<Vehicle>> list({String? plate});

  Future<PagedResult<Vehicle>> listPage({
    required int limit,
    required int offset,
  });

  Future<Vehicle> create(Map<String, dynamic> payload);

  Future<Vehicle> update(int id, Map<String, dynamic> payload);

  Future<void> delete(int id);
}

class DioVehicleRemoteDataSource implements VehicleRemoteDataSource {
  DioVehicleRemoteDataSource(this._dio);

  final Dio _dio;

  static const _path = '/api/vehicles';

  @override
  Future<List<Vehicle>> list({String? plate}) async {
    try {
      final response = await _dio.get(
        _path,
        queryParameters: plate != null ? {'plate': plate} : null,
      );
      return _parse(response.data);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<PagedResult<Vehicle>> listPage({
    required int limit,
    required int offset,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        _path,
        queryParameters: pageQuery(limit: limit, offset: offset),
      );
      return PagedResult(_parse(response.data), total: totalCountOf(response));
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  List<Vehicle> _parse(Object? data) => [
    for (final item in data as List<dynamic>)
      VehicleDto.fromJson(item as Map<String, dynamic>).toDomain(),
  ];

  @override
  Future<Vehicle> create(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(_path, data: payload);
      return VehicleDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<Vehicle> update(int id, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.patch('$_path/$id', data: payload);
      return VehicleDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _dio.delete('$_path/$id');
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
