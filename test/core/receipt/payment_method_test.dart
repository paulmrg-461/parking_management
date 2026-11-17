import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/failure_messages.dart';
import 'package:parking_management/core/network/supabase_error_mapper.dart';
import 'package:parking_management/core/receipt/payment_method.dart';
import 'package:parking_management/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  late AppLocalizations es;
  late AppLocalizations en;

  setUpAll(() async {
    es = await AppLocalizations.delegate.load(const Locale('es'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('Success: the online label is localized in ES and EN', () {
    expect(paymentMethodLabel(es, 'online'), 'En línea');
    expect(paymentMethodLabel(en, 'online'), 'Online');
  });

  test('Success: the online label wins over the enum fallback', () {
    // `PaymentMethod` has no online member on purpose (it drives the dialog),
    // so a naive fallback would render "Efectivo".
    expect(paymentMethodLabel(es, 'online'), isNot(es.paymentCash));
  });

  test('Failure: an unknown wire still maps to the cash fallback', () {
    expect(paymentMethodLabel(es, 'crypto'), es.paymentCash);
    expect(paymentMethodLabel(es, null), es.paymentUnknown);
  });

  test('Success: the new payment error codes are localized in both locales', () {
    const codes = [
      'OnlinePaymentsDisabledError',
      'NothingToPayError',
      'AmountTooLowError',
      'PaymentsNotConfiguredError',
      'PaymentThrottledError',
      'PaymentEventFailedError',
      'InvalidLinkError',
    ];
    for (final code in codes) {
      final failure = mapSupabaseError(
        sb.PostgrestException(message: code, code: 'P0001'),
      );
      expect(es.failure(failure), isNot(es.errorUnknown), reason: code);
      expect(en.failure(failure), isNot(en.errorUnknown), reason: code);
    }
  });
}
