import 'package:equatable/equatable.dart';

/// Base domain failure. [code] carries the backend's machine-readable error
/// code (`{"detail": ..., "code": ...}`) when present, for future i18n.
abstract class Failure extends Equatable {
  const Failure([this.message = '', this.code]);

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class StorageFailure extends Failure {
  const StorageFailure([
    super.message = 'Storage operation failed',
    super.code,
  ]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Network operation failed',
    super.code,
  ]);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation failed', super.code]);
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure([
    super.message = 'Authentication failed',
    super.code,
  ]);
}

/// The server was reached but could not complete the request right now
/// (5xx, 429, read/send timeout). Still a [NetworkFailure] so online-first
/// repositories fall back to their offline path, but the outbox retries it
/// with backoff instead of stopping the whole drain.
class ServerFailure extends NetworkFailure {
  const ServerFailure([
    super.message = 'Server temporarily unavailable',
    super.code,
  ]);
}

/// 429 Too Many Requests. [retryAfter] comes from the `Retry-After` header
/// (seconds) when the server sent a valid one.
class RateLimitedFailure extends ServerFailure {
  const RateLimitedFailure(String message, {this.retryAfter, String? code})
    : super(message, code);

  final Duration? retryAfter;

  @override
  List<Object?> get props => [...super.props, retryAfter];
}

/// Machine-readable codes for failures raised on the client (the backend
/// sends its own: the `DomainError` class name). Localized by
/// `FailureMessages` in presentation.
abstract final class ClientFailureCodes {
  static const emptyPlate = 'EmptyPlate';
  static const ocrNoText = 'OcrNoText';
  static const scanUnavailable = 'ScanUnavailable';
  static const tooManyPhotos = 'TooManyPhotos';
  static const photoTooLarge = 'PhotoTooLargeError';
  static const pendingSyncCheckOut = 'PendingSyncCheckOut';
  static const missingPendingPhoto = 'MissingPendingPhoto';
}
