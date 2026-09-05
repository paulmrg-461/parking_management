import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../domain/entities/tariff.dart';
import 'models/tariff_dto.dart';

abstract class TariffRemoteDataSource {
  Future<List<Tariff>> list(String token);

  Future<Tariff> create(String token, Map<String, dynamic> payload);

  Future<Tariff> update(String token, int id, Map<String, dynamic> payload);

  Future<void> delete(String token, int id);
}

class DioTariffRemoteDataSource implements TariffRemoteDataSource {
  DioTariffRemoteDataSource(this._dio);

  final Dio _dio;

  static const _path = '/api/tariffs';

  @override
  Future<List<Tariff>> list(String token) async {
    try {
      final response = await _dio.get(
        _path,
        options: Options(headers: _auth(token)),
      );
      final data = response.data as List<dynamic>;
      return data
          .map((item) => TariffDto.fromJson(item as Map<String, dynamic>).toDomain())
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<Tariff> create(String token, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        _path,
        data: payload,
        options: Options(headers: _auth(token)),
      );
      return TariffDto.fromJson(response.data as Map<String, dynamic>).toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<Tariff> update(String token, int id, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.patch(
        '$_path/$id',
        data: payload,
        options: Options(headers: _auth(token)),
      );
      return TariffDto.fromJson(response.data as Map<String, dynamic>).toDomain();
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
