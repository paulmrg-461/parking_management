import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_error_mapper.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/sync/pending_photo_storage.dart';
import '../domain/entities/new_vehicle_info.dart';
import '../domain/entities/parking_session.dart';
import 'models/parking_session_dto.dart';

abstract class CheckInRemoteDataSource {
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
    String? idempotencyKey,
  });

  Future<List<ParkingSession>> listOpenSessions();
}

class DioCheckInRemoteDataSource implements CheckInRemoteDataSource {
  DioCheckInRemoteDataSource(this._dio);

  final Dio _dio;

  static const _path = '/api/check-ins';

  @override
  Future<ParkingSession> createCheckIn({
    required String plate,
    required List<XFile> photos,
    NewVehicleInfo? newVehicle,
    String? idempotencyKey,
  }) async {
    try {
      final formData = FormData.fromMap({
        'plate': plate,
        ..._newVehicleFields(newVehicle),
        'photos': [
          for (var i = 0; i < photos.length; i++) await _part(photos[i], i),
        ],
      });
      final response = await _dio.post(
        _path,
        data: formData,
        options: idempotencyOptions(idempotencyKey),
      );
      return ParkingSessionDto.fromJson(response.data as Map<String, dynamic>)
          .toDomain();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  @override
  Future<List<ParkingSession>> listOpenSessions() async {
    try {
      final response = await _dio.get(_path);
      final data = response.data as List<dynamic>;
      return data
          .map(
            (item) =>
                ParkingSessionDto.fromJson(item as Map<String, dynamic>)
                    .toDomain(),
          )
          .toList();
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }

  /// Bytes-based (works on web). The file name is synthetic so no device
  /// path leaks to the server; the MIME type drives backend validation.
  Future<MultipartFile> _part(XFile photo, int index) async {
    final extension = photoExtensionOf(photo);
    return MultipartFile.fromBytes(
      await photo.readAsBytes(),
      filename: 'photo_$index$extension',
      contentType: DioMediaType.parse(photoMimeType(extension)),
    );
  }

  Map<String, Object> _newVehicleFields(NewVehicleInfo? info) {
    if (info == null) {
      return const {};
    }
    return {
      'category_id': info.categoryId,
      if (info.color != null) 'color': info.color!,
      if (info.brand != null) 'brand': info.brand!,
    };
  }
}
