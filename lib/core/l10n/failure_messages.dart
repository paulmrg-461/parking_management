import '../error/failure.dart';
import '../../l10n/app_localizations.dart';

/// Must match the text `mapDioError` uses for a 403 without a `code`.
const _forbiddenDetail = 'Forbidden';

/// Localizes a [Failure] for the UI: known `code`s (backend `DomainError`
/// class names or [ClientFailureCodes]) get a Spanish/English text; unknown
/// ones fall back by failure type, and validation failures without a known
/// code show the backend `detail` as-is.
extension FailureMessages on AppLocalizations {
  String failure(Failure failure) =>
      _rateLimited(failure) ?? _byCode(failure.code) ?? _byType(failure);

  /// [failure] when present, else the raw [message] (legacy states).
  String errorText(String message, Failure? failure) =>
      failure == null ? message : this.failure(failure);

  String? _rateLimited(Failure failure) {
    if (failure is! RateLimitedFailure) {
      return null;
    }
    final retry = failure.retryAfter;
    if (retry == null) {
      return errorTooManyAttempts;
    }
    final minutes = (retry.inSeconds / 60).ceil();
    return errorRateLimited(minutes < 1 ? 1 : minutes);
  }

  String? _byCode(String? code) => switch (code) {
    null => null,
    'InvalidCredentialsError' => errorAuth,
    'InvalidTokenError' => errorSessionExpired,
    'AdminRequiredError' || 'PermissionDeniedError' => errorForbidden,
    'VehicleNotFoundError' => errorVehicleNotFound,
    'CategoryNotFoundError' => errorCategoryNotFound,
    'TariffNotFoundError' => errorTariffNotFound,
    'UserNotFoundError' => errorUserNotFound,
    'MonthlyPassNotFoundError' => errorMonthlyPassNotFound,
    'SessionNotFoundError' => errorSessionNotFound,
    'MissingHourlyTariffError' => errorMissingHourlyTariff,
    'NotFoundError' => errorNotFound,
    'DuplicateOpenSessionError' => errorDuplicateOpenSession,
    'DuplicatePlateError' => errorDuplicatePlate,
    'DuplicateCategoryNameError' => errorDuplicateCategory,
    'DuplicateUsernameError' => errorDuplicateUsername,
    'SessionAlreadyClosedError' => errorSessionAlreadyClosed,
    'IdempotencyKeyInUseError' ||
    'IdempotencyKeyMismatchError' => errorIdempotency,
    'ConflictError' => errorConflict,
    'VehicleNotRegisteredError' => errorVehicleNotRegistered,
    'InvalidPhotoError' => errorInvalidPhoto,
    'PhotoTooLargeError' || 'PayloadTooLargeError' => errorPhotoTooLarge,
    'InternalError' => errorServer,
    ClientFailureCodes.emptyPlate => errorEmptyPlate,
    ClientFailureCodes.ocrNoText => errorOcrNoText,
    ClientFailureCodes.scanUnavailable => errorScanUnavailable,
    ClientFailureCodes.tooManyPhotos => errorTooManyPhotos,
    ClientFailureCodes.pendingSyncCheckOut => errorPendingSyncCheckOut,
    ClientFailureCodes.missingPendingPhoto => errorMissingPendingPhoto,
    _ => null,
  };

  String _byType(Failure failure) => switch (failure) {
    ServerFailure() => errorServer,
    NetworkFailure() => errorNetwork,
    StorageFailure() => errorStorage,
    AuthenticationFailure(message: _forbiddenDetail) => errorForbidden,
    AuthenticationFailure() => errorAuth,
    _ when failure.message.isNotEmpty => failure.message,
    _ => errorUnknown,
  };
}
