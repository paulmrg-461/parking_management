import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/error/failure.dart';
import 'package:parking_management/core/l10n/failure_messages.dart';
import 'package:parking_management/core/l10n/l10n.dart';

void main() {
  late AppLocalizations es;

  setUpAll(() async {
    es = await AppLocalizations.delegate.load(const Locale('es'));
  });

  test('Success: a known backend code is localized to Spanish', () {
    const failure = ValidationFailure(
      'Session already closed',
      'SessionAlreadyClosedError',
    );
    expect(es.failure(failure), 'Esta salida ya fue registrada');
  });

  test('Success: client codes are localized too', () {
    const failure = ValidationFailure('x', ClientFailureCodes.emptyPlate);
    expect(es.failure(failure), 'Ingresa la placa');
  });

  test('Failure: unknown code falls back to the backend detail', () {
    const failure = ValidationFailure('PIN must be 4 to 6 digits', 'Weird');
    expect(es.failure(failure), 'PIN must be 4 to 6 digits');
  });

  test('Failure: network/server failures get generic Spanish texts', () {
    expect(es.failure(const NetworkFailure('x')), es.errorNetwork);
    expect(es.failure(const ServerFailure('x')), es.errorServer);
  });

  test('Security: auth failures never echo raw server text', () {
    expect(
      es.failure(const AuthenticationFailure('Invalid credentials')),
      'Usuario o PIN incorrectos',
    );
    expect(
      es.failure(const AuthenticationFailure('Forbidden')),
      es.errorForbidden,
    );
  });

  test('Rate limited: shows the minutes to wait', () {
    const failure = RateLimitedFailure(
      'Too many',
      retryAfter: Duration(seconds: 90),
    );
    expect(
      es.failure(failure),
      'Demasiados intentos. Intenta de nuevo en 2 min',
    );
  });

  group('billing and evidence integrity codes', () {
    late AppLocalizations en;

    setUpAll(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
    });

    const codes = [
      'LostTicketPassMethodError',
      'StaleExitTimeError',
      'EvidenceNotFoundError',
      'EvidenceAlreadyUsedError',
    ];

    test('Success: each code has its own Spanish and English text', () {
      for (final code in codes) {
        final failure = ValidationFailure(code, code);
        expect(es.failure(failure), isNot(code), reason: code);
        expect(en.failure(failure), isNot(code), reason: code);
      }
      expect(
        codes.map((c) => es.failure(ValidationFailure(c, c))).toSet(),
        hasLength(4),
      );
    });

    test('Failure: the raw P0001 message maps to the localized code', () {
      expect(
        es.failure(
          const ValidationFailure('StaleExitTimeError', 'StaleExitTimeError'),
        ),
        es.errorStaleExitTime,
      );
    });

    test('Security: a rejected pass method on a lost ticket is explained', () {
      expect(
        en.failure(const ValidationFailure('x', 'LostTicketPassMethodError')),
        en.errorLostTicketPassMethod,
      );
    });
  });
}
