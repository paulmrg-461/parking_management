/// Evidence-photo limits enforced by the backend (JPEG/PNG only, 413/422
/// otherwise); mirrored client-side so the operator gets immediate feedback.
abstract final class EvidencePolicy {
  static const maxPhotos = 5;
  static const maxPhotoBytes = 5 * 1024 * 1024;

  /// One optional walk-around video, capped like the storage bucket allows.
  static const maxVideoBytes = 50 * 1024 * 1024;
  static const maxVideoSeconds = 60;
}
