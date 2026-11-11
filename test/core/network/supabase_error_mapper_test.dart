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

    expect(
      failure,
      const ValidationFailure(
        'DuplicateOpenSessionError',
        'DuplicateOpenSessionError',
      ),
    );
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

    expect(
      failure,
      const ValidationFailure('AdminRequiredError', 'AdminRequiredError'),
    );
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

  group('transient and session errors', () {
    tearDown(() => hasAuthSession = () => true);

    test('Failure: gateway 5xx without a JSON body is a server failure', () {
      for (final code in ['500', '502', '503', '504']) {
        final failure = mapSupabaseError(
          PostgrestException(message: 'Bad gateway', code: code),
        );
        expect(failure, isA<ServerFailure>(), reason: code);
      }
    });

    test('Failure: serialization, deadlock, timeout and pool errors retry', () {
      for (final code in ['40001', '40P01', '57014', '53300']) {
        final failure = mapSupabaseError(
          PostgrestException(message: 'busy', code: code),
        );
        expect(failure, isA<ServerFailure>(), reason: code);
      }
    });

    test('Security: PGRST303 (bad JWT claims) is an auth failure', () {
      final failure = mapSupabaseError(
        const PostgrestException(message: 'JWT claims', code: 'PGRST303'),
      );

      expect(failure, isA<AuthenticationFailure>());
    });

    test(
      'Security: InvalidTokenError (message or hint) is an auth failure',
      () {
        final byMessage = mapSupabaseError(
          const PostgrestException(message: 'InvalidTokenError', code: 'P0001'),
        );
        final byHint = mapSupabaseError(
          const PostgrestException(
            message: 'raised',
            code: 'P0001',
            hint: 'InvalidTokenError',
          ),
        );

        expect(byMessage, isA<AuthenticationFailure>());
        expect(byMessage.code, 'InvalidTokenError');
        expect(byHint, isA<AuthenticationFailure>());
      },
    );

    test('Security: 42501 without a session is an auth failure', () {
      hasAuthSession = () => false;

      final failure = mapSupabaseError(
        const PostgrestException(message: 'denied', code: '42501'),
      );

      expect(failure, isA<AuthenticationFailure>());
    });
  });

  test('Security: integrity codes are non-retryable validation failures', () {
    for (final code in [
      'LostTicketPassMethodError',
      'StaleExitTimeError',
      'EvidenceNotFoundError',
      'EvidenceAlreadyUsedError',
    ]) {
      final viaRpc = mapSupabaseError(
        PostgrestException(message: code, code: 'P0001'),
      );
      final viaFunction = mapSupabaseError(
        FunctionException(status: 409, details: {'message': code}),
      );
      expect(viaRpc, ValidationFailure(code, code), reason: code);
      expect(viaFunction.code, code, reason: code);
    }
  });

  test('Success: an already typed failure keeps its identity', () {
    const conflict = VersionConflictFailure({'id': 1, 'version': 3});

    expect(mapSupabaseError(conflict), same(conflict));
  });
}
