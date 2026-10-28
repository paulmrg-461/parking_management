/// Supported site currencies. Amounts are integers in the currency's **minor
/// unit** (COP pesos, USD cents); the currency decides how to show/parse them.
enum Currency {
  cop('COP', r'$', 0),
  usd('USD', r'US$', 2);

  const Currency(this.code, this.symbol, this.decimals);

  final String code;
  final String symbol;
  final int decimals;

  int get scale => decimals == 0 ? 1 : 100;

  /// Cash denominations in minor units, biggest first.
  List<int> get denominations => switch (this) {
    Currency.cop => const [
      100000,
      50000,
      20000,
      10000,
      5000,
      2000,
      1000,
      500,
      200,
      100,
    ],
    Currency.usd => const [
      10000,
      5000,
      2000,
      1000,
      500,
      200,
      100,
      25,
      10,
      5,
      1,
    ],
  };

  static Currency fromCode(String? code) => switch (code?.toUpperCase()) {
    'USD' => Currency.usd,
    _ => Currency.cop,
  };
}
