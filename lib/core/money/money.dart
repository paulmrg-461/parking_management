import 'currency.dart';

/// Ambient money formatting for the active site. The app has exactly one
/// active lot at a time, so the currency is configured when its settings load
/// (and after saving Ajustes); every amount in the UI/PDF/thermal receipts goes
/// through these helpers.
class Money {
  Money._();

  static Currency _currency = Currency.cop;

  static Currency get currency => _currency;

  /// Called by [BrandingCubit] whenever the site settings are (re)loaded.
  static void configure(Currency currency) {
    _currency = currency;
  }

  /// `$5.000` (COP) / `US$50.00` (USD). Amounts are minor units.
  static String format(int minor) {
    final currency = _currency;
    final negative = minor < 0;
    final abs = minor.abs();
    final major = currency.decimals == 0
        ? '$abs'
        : '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
    return '${negative ? '-' : ''}${currency.symbol}'
        '${_group(major, currency == Currency.cop ? '.' : ',')}';
  }

  /// Editable text for a money input: `5000` / `50.00` (no symbol/grouping).
  static String input(int minor) {
    if (_currency.decimals == 0) {
      return '$minor';
    }
    final negative = minor < 0;
    final abs = minor.abs();
    return '${negative ? '-' : ''}${abs ~/ 100}.'
        '${(abs % 100).toString().padLeft(2, '0')}';
  }

  /// Parses operator input (accepts `.`/`,` decimals and thousands grouping)
  /// into minor units. `null` when there is no number.
  static int? parse(String? value) {
    var text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    final negative = text.startsWith('-');
    text = text.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (text.isEmpty) {
      return null;
    }
    final decimals = _currency.decimals;
    String integerPart;
    String fractionPart = '';
    if (decimals == 0) {
      integerPart = text.replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      final lastDot = text.lastIndexOf('.');
      final lastComma = text.lastIndexOf(',');
      final separator = lastDot > lastComma ? lastDot : lastComma;
      if (separator < 0) {
        integerPart = text.replaceAll(RegExp(r'[^0-9]'), '');
      } else {
        final tail = text.substring(separator + 1);
        final head = text.substring(0, separator);
        final tailDigits = tail.replaceAll(RegExp(r'[^0-9]'), '');
        if (tailDigits.isEmpty || tailDigits.length > decimals) {
          // Grouping separator (e.g. `5,000`): treat as whole units.
          integerPart = text.replaceAll(RegExp(r'[^0-9]'), '');
        } else {
          integerPart = head.replaceAll(RegExp(r'[^0-9]'), '');
          fractionPart = tailDigits.padRight(decimals, '0');
        }
      }
    }
    if (integerPart.isEmpty && fractionPart.isEmpty) {
      return null;
    }
    final major = int.tryParse(integerPart.isEmpty ? '0' : integerPart);
    if (major == null) {
      return null;
    }
    final minor = decimals == 0
        ? major
        : major * 100 + (int.tryParse(fractionPart) ?? 0);
    return negative ? -minor : minor;
  }

  /// Whole major units, for CSV/spreadsheet exports (`50.5` for USD).
  static String major(int minor) {
    if (_currency.decimals == 0) {
      return '$minor';
    }
    final negative = minor < 0;
    final abs = minor.abs();
    return '${negative ? '-' : ''}${abs ~/ 100}.'
        '${(abs % 100).toString().padLeft(2, '0')}';
  }

  static String _group(String value, String separator) {
    final dot = value.indexOf('.');
    final integer = dot == -1 ? value : value.substring(0, dot);
    final fraction = dot == -1 ? '' : value.substring(dot);
    final buffer = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      if (i > 0 && (integer.length - i) % 3 == 0) {
        buffer.write(separator);
      }
      buffer.write(integer[i]);
    }
    return '${buffer.toString()}$fraction';
  }
}
