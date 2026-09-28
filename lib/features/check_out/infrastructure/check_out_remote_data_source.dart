import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/network/pagination.dart';
import '../../../core/pagination/paged_result.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/entities/open_session.dart';
import 'models/check_out_receipt_dto.dart';
import 'models/open_session_dto.dart';

abstract class CheckOutRemoteDataSource {
  Future<PagedResult<OpenSession>> listOpenSessions({
    required int limit,
    required int offset,
  });

  /// [clientExitTime] / [idempotencyKey] are only sent by replays (as the
  /// `client_exit_time` body field — always UTC with offset, the backend
  /// rejects naive datetimes — and `Idempotency-Key` header); the online
  /// path omits both.
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    DateTime? clientExitTime,
    String? idempotencyKey,
  });
}

class DioCheckOutRemoteDataSource implements CheckOutRemoteDataSource {
  DioCheckOutRemoteDataSource(this._dio);

  final Dio _dio;

  static const _checkInsPath = '/api/check-ins';
  static const _checkOutsPath = '/api/check-outs';

  @override
  Future<PagedResult<OpenSession>> listOpenSessions({
    required int limit,
    required int offset,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        _checkInsPath,
        queryParameters: pageQuery(limit: limit, offset: offset),
      );
      return PagedResult([
        for (final item in response.data ?? const <dynamic>[])
          OpenSessionDto.fromJson(item as Map<String, dynamic>).toDomain(),
      ], total: totalCountOf(response));
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<CheckOutReceipt> checkOut(
    int sessionId, {
    DateTime? clientExitTime,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        '$_checkOutsPath/$sessionId',
        data: clientExitTime != null
            ? {'client_exit_time': clientExitTime.toUtc().toIso8601String()}
            : null,
        options: idempotencyOptions(idempotencyKey),
      );
      return CheckOutReceiptDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}
