/// Evidence-photo limits enforced by the backend (JPEG/PNG only, 413/422
/// otherwise); mirrored client-side so the operator gets immediate feedback.
abstract final class EvidencePolicy {
  static const maxPhotos = 5;
  static const maxPhotoBytes = 5 * 1024 * 1024;
}
