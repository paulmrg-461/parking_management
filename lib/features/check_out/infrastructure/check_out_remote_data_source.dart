import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/entities/open_session.dart';
import 'models/check_out_receipt_dto.dart';
import 'models/open_session_dto.dart';

abstract class CheckOutRemoteDataSource {
  Future<List<OpenSession>> listOpenSessions(String token);

  /// [clientExitTime], when present, is sent as `client_exit_time` in the
  /// POST body (used by replay); the online path omits it, unchanged.
  Future<CheckOutReceipt> checkOut(
    String token,
    int sessionId, {
    DateTime? clientExitTime,
  });
}

class DioCheckOutRemoteDataSource implements CheckOutRemoteDataSource {
  DioCheckOutRemoteDataSource(this._dio);

  final Dio _dio;

  static const _checkInsPath = '/api/check-ins';
  static const _checkOutsPath = '/api/check-outs';

  @override
  Future<List<OpenSession>> listOpenSessions(String token) async {
    try {
      final response = await _dio.get(
        _checkInsPath,
        options: Options(headers: _auth(token)),
      );
      final data = response.data as List<dynamic>;
      return data
          .map((item) =>
              OpenSessionDto.fromJson(item as Map<String, dynamic>).toDomain())
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<CheckOutReceipt> checkOut(
    String token,
    int sessionId, {
    DateTime? clientExitTime,
  }) async {
    try {
      final response = await _dio.post(
        '$_checkOutsPath/$sessionId',
        data: clientExitTime != null
            ? {'client_exit_time': clientExitTime.toIso8601String()}
            : null,
        options: Options(headers: _auth(token)),
      );
      return CheckOutReceiptDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token'};
}
