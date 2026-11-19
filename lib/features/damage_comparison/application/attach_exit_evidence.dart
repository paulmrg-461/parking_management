import 'package:cross_file/cross_file.dart';

import '../../../core/error/failure.dart';
import '../infrastructure/exit_evidence_remote_data_source.dart';

/// Uploads the optional exit photos after a successful online check-out.
/// It never blocks or fails the check-out; the caller gets null on error.
class AttachExitEvidence {
  const AttachExitEvidence(this._repository);

  final ExitEvidenceRemoteDataSource _repository;

  Future<int?> call({
    required int sessionId,
    required List<XFile> photos,
    required String clientRef,
  }) async {
    if (photos.isEmpty) {
      return null;
    }
    if (photos.length > 5) {
      throw const ValidationFailure('EvidenceLimitError', 'EvidenceLimitError');
    }
    for (final photo in photos) {
      try {
        if (await _length(photo) > 5 * 1024 * 1024) {
          throw const ValidationFailure(
            'PhotoTooLargeError',
            'PhotoTooLargeError',
          );
        }
      } on ValidationFailure {
        rethrow;
      } catch (_) {
        // An unreadable file will be rejected by the upload path; keep going.
      }
    }
    try {
      return await _repository.attach(
        sessionId: sessionId,
        photos: photos,
        clientRef: clientRef,
      );
    } on Failure {
      return null;
    }
  }

  Future<int> _length(XFile photo) async {
    final bytes = await photo.readAsBytes();
    return bytes.length;
  }
}
