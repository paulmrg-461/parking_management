import '../money/money.dart';

/// Backwards-compatible COP-style helper: now currency-aware (see [Money]).
class CopFormatter {
  CopFormatter._();

  static String format(int amount) => Money.format(amount);

  static int? parse(String value) => Money.parse(value);
}
