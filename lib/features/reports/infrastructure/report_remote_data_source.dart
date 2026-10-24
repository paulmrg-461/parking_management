import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../domain/entities/occupancy_report.dart';
import '../domain/entities/revenue_report.dart';
import '../domain/entities/whatsapp_report.dart';
import 'models/occupancy_report_dto.dart';
import 'models/revenue_report_dto.dart';

abstract class ReportRemoteDataSource {
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    bool allLots = false,
  });

  Future<OccupancyReport> getOccupancyReport();

  Future<WhatsappReport> getWhatsappReport({
    required DateTime startDate,
    required DateTime endDate,
  });
}

class SupabaseReportRemoteDataSource implements ReportRemoteDataSource {
  SupabaseReportRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    bool allLots = false,
  }) async {
    try {
      final result = await _client.rpc(
        allLots ? 'report_revenue_all' : 'report_revenue',
        params: {
          'p_start_date': _formatDate(startDate),
          'p_end_date': _formatDate(endDate),
        },
      );
      return RevenueReportDto.fromJson(
        Map<String, dynamic>.from(result as Map),
      ).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<OccupancyReport> getOccupancyReport() async {
    try {
      final result = await _client.rpc('report_occupancy');
      return OccupancyReportDto.fromJson(
        Map<String, dynamic>.from(result as Map),
      ).toDomain();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<WhatsappReport> getWhatsappReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final result = await _client.rpc(
        'report_whatsapp',
        params: {
          'p_start_date': _formatDate(startDate),
          'p_end_date': _formatDate(endDate),
        },
      );
      return WhatsappReport.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
