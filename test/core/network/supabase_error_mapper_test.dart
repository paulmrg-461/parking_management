import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/network/supabase_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

void main() {
  test('Success: SQL domain messages keep their code for localization', () {
    final failure = mapSupabaseError(
      const PostgrestException(
        message: 'DuplicateOpenSessionError',
        code: 'P0001',
      ),
    );

    expect(failure, const ValidationFailure('DuplicateOpenSessionError', 'DuplicateOpenSessionError'));
  });

  test('Failure: constraint violations are invalid data', () {
    final failure = mapSupabaseError(
      const PostgrestException(message: 'check failed', code: '23514'),
    );

    expect(failure, isA<ValidationFailure>());
    expect(failure.code, 'InvalidDataError');
  });

  test('Security: anon/RLS denials are forbidden, not auth failures', () {
    final failure = mapSupabaseError(
      const PostgrestException(message: 'denied', code: '42501'),
    );

    expect(failure, isA<ValidationFailure>());
    expect(failure.code, 'PermissionDeniedError');
  });

  test('Security: Edge Function admin checks map to a forbidden code', () {
    final failure = mapSupabaseError(
      const FunctionException(
        status: 403,
        details: {'message': 'AdminRequiredError'},
      ),
    );

    expect(failure, const ValidationFailure('AdminRequiredError', 'AdminRequiredError'));
  });

  test('Failure: network errors are offline failures', () {
    expect(mapSupabaseError(ClientException('down')), isA<NetworkFailure>());
    expect(mapSupabaseError(TimeoutException('slow')), isA<NetworkFailure>());
  });

  test('Security: capacity errors keep the code for the localized message', () {
    for (final code in [
      'CategoryFullError',
      'ParkingFullError',
      'KeysFullError',
    ]) {
      final failure = mapSupabaseError(
        PostgrestException(message: code, code: 'P0001'),
      );
      expect(failure, isA<ValidationFailure>());
      expect(failure.code, code);
    }
  });
}
