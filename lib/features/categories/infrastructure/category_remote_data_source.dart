import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../domain/entities/category.dart';
import 'models/category_dto.dart';

abstract class CategoryRemoteDataSource {
  Future<List<Category>> list();

  Future<Category> create(String name);

  Future<Category> update(int id, String name);

  Future<void> delete(int id);
}

class DioCategoryRemoteDataSource implements CategoryRemoteDataSource {
  DioCategoryRemoteDataSource(this._dio);

  final Dio _dio;

  static const _path = '/api/categories';

  @override
  Future<List<Category>> list() async {
    try {
      final response = await _dio.get(_path);
      final data = response.data as List<dynamic>;
      return data
          .map(
            (item) =>
                CategoryDto.fromJson(item as Map<String, dynamic>).toDomain(),
          )
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<Category> create(String name) async {
    try {
      final response = await _dio.post(_path, data: {'name': name});
      return CategoryDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<Category> update(int id, String name) async {
    try {
      final response = await _dio.patch('$_path/$id', data: {'name': name});
      return CategoryDto.fromJson(response.data as Map<String, dynamic>)
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
