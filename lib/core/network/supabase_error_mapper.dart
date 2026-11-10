import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../error/failure.dart';

/// Backend `DomainError` class names raised by the SQL RPCs. The presentation
/// layer localizes them through `FailureMessages`.
const _domainCodes = {
  'AdminRequiredError',
  'AuthenticationError',
  'CategoryNotFoundError',
  'ConflictError',
  'DuplicateCategoryNameError',
  'DuplicateOpenSessionError',
  'DuplicatePlateError',
  'DuplicateUsernameError',
  'EvidenceAlreadyUsedError',
  'EvidenceNotFoundError',
  'InvalidBillingPeriodError',
  'InvalidEntryTimeError',
  'InvalidExitTimeError',
  'InvalidNameError',
  'InvalidReportRangeError',
  'InvalidTokenError',
  'LostTicketPassMethodError',
  'MissingHourlyTariffError',
  'SessionAlreadyClosedError',
  'SessionNotFoundError',
  'StaleExitTimeError',
  'UserNotFoundError',
  'VehicleNotFoundError',
  'VehicleNotRegisteredError',
};

/// Maps Supabase client errors (PostgREST, Storage, Functions, Auth) to the
/// app's [Failure] hierarchy.
Failure mapSupabaseError(Object error) {
  if (error is sb.PostgrestException) {
    return _postgrest(error);
  }
  if (error is sb.AuthException) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 429) {
      return RateLimitedFailure(error.message);
    }
    if (status != null && status >= 500) {
      return ServerFailure(error.message);
    }
    return AuthenticationFailure(error.message, error.code);
  }
  if (error is sb.StorageException) {
    return _status(error.statusCode, error.message) ??
        ServerFailure(error.message);
  }
  if (error is sb.FunctionException) {
    final message = _functionMessage(error);
    return _status(error.status, message) ?? ValidationFailure(message);
  }
  if (error is ClientException ||
      error is TimeoutException ||
      error.runtimeType.toString().contains('SocketException')) {
    return const NetworkFailure('Unable to reach the server');
  }
  return ServerFailure(error.runtimeType.toString());
}

/// Whether a GoTrue session is present. Swapped in tests; defaults to `true`
/// when Supabase is not initialized so an RLS denial stays "forbidden".
@visibleForTesting
bool Function() hasAuthSession = _currentSessionExists;

bool _currentSessionExists() {
  try {
    return sb.Supabase.instance.client.auth.currentSession != null;
  } on Object {
    return true;
  }
}

/// SQLSTATEs that mean "try again later": serialization failure, deadlock,
/// statement timeout and too many connections.
const _transientCodes = {'40001', '40P01', '57014', '53300'};

Failure _postgrest(sb.PostgrestException error) {
  final message = error.message;
  if (_isInvalidToken(error)) {
    return const AuthenticationFailure(
      'Invalid credentials',
      'InvalidTokenError',
    );
  }
  if (_domainCodes.contains(message)) {
    return ValidationFailure(message, message);
  }
  return _transient(error) ?? _postgrestCode(error);
}

bool _isInvalidToken(sb.PostgrestException error) =>
    error.message == 'InvalidTokenError' || error.hint == 'InvalidTokenError';

Failure? _transient(sb.PostgrestException error) {
  if (_isHttp5xx(error.code) || _transientCodes.contains(error.code)) {
    return ServerFailure(error.message);
  }
  return null;
}

/// PostgREST falls back to the HTTP status as `code` when the body is not
/// JSON (gateway errors). SQLSTATEs are five characters, so only a
/// three-digit code is an HTTP status.
bool _isHttp5xx(String? code) {
  final status = code != null && code.length == 3 ? int.tryParse(code) : null;
  return status != null && status >= 500;
}

Failure _postgrestCode(sb.PostgrestException error) {
  final message = error.message;
  switch (error.code) {
    case '42501': // insufficient privilege / RLS denial
      return hasAuthSession()
          ? const ValidationFailure('Forbidden', 'PermissionDeniedError')
          : const AuthenticationFailure('Invalid credentials');
    case '23505': // unique_violation
      return ValidationFailure(
        message,
        message.contains('plate') ? 'DuplicatePlateError' : 'ConflictError',
      );
    case '23503': // foreign key violation
      return ValidationFailure(message, 'ConflictError');
    case '23514': // check constraint
      return ValidationFailure(message, 'InvalidDataError');
    case 'PGRST116': // 0 rows for .single()
      return const ValidationFailure('Not found', 'NotFoundError');
    case 'PGRST301' || 'PGRST303': // JWT expired / invalid claims
      return const AuthenticationFailure('Invalid credentials');
    case 'P0001':
      return ValidationFailure(message, message);
    default:
      return ValidationFailure(message);
  }
}

Failure? _status(Object? rawStatus, String message) {
  final status = rawStatus is int ? rawStatus : int.tryParse('$rawStatus');
  if (status == 401) {
    return AuthenticationFailure(message);
  }
  if (status == 403) {
    return ValidationFailure(
      message,
      _domainCodes.contains(message) ? message : 'PermissionDeniedError',
    );
  }
  if (status == 429) {
    return RateLimitedFailure(message);
  }
  if (status != null && status >= 500) {
    return ServerFailure(message);
  }
  if (status == 400 || status == 404 || status == 409 || status == 422) {
    return ValidationFailure(
      message,
      _domainCodes.contains(message) ? message : null,
    );
  }
  return null;
}

String _functionMessage(sb.FunctionException error) {
  final details = error.details;
  if (details is Map && details['message'] is String) {
    return details['message'] as String;
  }
  if (details is String && details.isNotEmpty) {
    return details;
  }
  return 'Function failed';
}
