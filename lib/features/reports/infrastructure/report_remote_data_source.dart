import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../domain/entities/occupancy_report.dart';
import '../domain/entities/revenue_report.dart';
import 'models/occupancy_report_dto.dart';
import 'models/revenue_report_dto.dart';

abstract class ReportRemoteDataSource {
  Future<RevenueReport> getRevenueReport(
    String token, {
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<OccupancyReport> getOccupancyReport(String token);
}

class DioReportRemoteDataSource implements ReportRemoteDataSource {
  DioReportRemoteDataSource(this._dio);

  final Dio _dio;

  static const _revenuePath = '/api/reports/revenue';
  static const _occupancyPath = '/api/reports/occupancy';

  @override
  Future<RevenueReport> getRevenueReport(
    String token, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _dio.get(
        _revenuePath,
        queryParameters: {
          'start_date': _formatDate(startDate),
          'end_date': _formatDate(endDate),
        },
        options: Options(headers: _auth(token)),
      );
      return RevenueReportDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<OccupancyReport> getOccupancyReport(String token) async {
    try {
      final response = await _dio.get(
        _occupancyPath,
        options: Options(headers: _auth(token)),
      );
      return OccupancyReportDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token'};

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
