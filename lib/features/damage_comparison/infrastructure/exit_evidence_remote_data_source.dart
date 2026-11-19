import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_error_mapper.dart';
import '../../../core/sync/pending_photo_storage.dart';

abstract class ExitEvidenceRemoteDataSource {
  Future<int> attach({
    required int sessionId,
    required List<XFile> photos,
    required String clientRef,
  });
}

class SupabaseExitEvidenceRemoteDataSource
    implements ExitEvidenceRemoteDataSource {
  SupabaseExitEvidenceRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<int> attach({
    required int sessionId,
    required List<XFile> photos,
    required String clientRef,
  }) async {
    final paths = <Map<String, dynamic>>[];
    try {
      for (var index = 0; index < photos.length; index++) {
        final photo = photos[index];
        final extension = photoExtensionOf(photo);
        final path = 'exit-$sessionId-$clientRef/$index$extension';
        try {
          await _client.storage.from('evidence').uploadBinary(
            path,
            await photo.readAsBytes(),
            fileOptions: FileOptions(contentType: photoMimeType(extension)),
          );
        } on StorageException catch (error) {
          // A retry that hit an already uploaded object is a success.
          if (error.statusCode != '409') {
            rethrow;
          }
        }
        paths.add({'path': path, 'taken_at': DateTime.now().toIso8601String()});
      }
      final result = await _client.rpc(
        'add_exit_evidence',
        params: {'p_session_id': sessionId, 'p_photos': paths},
      );
      final map = Map<String, dynamic>.from(result as Map);
      return (map['exit_photo_count'] as num?)?.toInt() ?? paths.length;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}

class ExitEvidenceRepositoryImpl implements ExitEvidenceRemoteDataSource {
  ExitEvidenceRepositoryImpl(this._remote);

  final ExitEvidenceRemoteDataSource _remote;

  @override
  Future<int> attach({
    required int sessionId,
    required List<XFile> photos,
    required String clientRef,
  }) => _remote.attach(
    sessionId: sessionId,
    photos: photos,
    clientRef: clientRef,
  );
}
