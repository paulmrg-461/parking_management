import 'dart:async';

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
  'InvalidBillingPeriodError',
  'InvalidEntryTimeError',
  'InvalidExitTimeError',
  'InvalidReportRangeError',
  'InvalidTokenError',
  'MissingHourlyTariffError',
  'SessionAlreadyClosedError',
  'SessionNotFoundError',
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

Failure _postgrest(sb.PostgrestException error) {
  final code = error.code;
  final message = error.message;
  if (_domainCodes.contains(message)) {
    return ValidationFailure(message, message);
  }
  switch (code) {
    case '42501': // insufficient privilege / RLS denial
      return const ValidationFailure('Forbidden', 'PermissionDeniedError');
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
    case 'PGRST301': // JWT expired
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
    return ValidationFailure(message, _domainCodes.contains(message) ? message : null);
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
