import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/money/currency.dart';
import 'package:parking_management/core/money/money.dart';
import 'package:parking_management/core/utils/cop_formatter.dart';

void main() {
  tearDown(() => Money.configure(Currency.cop));

  test('Success: COP formats and parses whole pesos', () {
    Money.configure(Currency.cop);

    expect(Money.format(5000), r'$5.000');
    expect(Money.format(1500000), r'$1.500.000');
    expect(Money.format(-2500), r'-$2.500');
    expect(Money.parse('5.000'), 5000);
    expect(Money.parse('5,000'), 5000);
    expect(Money.input(5000), '5000');
    expect(CopFormatter.format(5000), r'$5.000');
  });

  test('Success: USD formats cents with US grouping', () {
    Money.configure(Currency.usd);

    expect(Money.format(5000), r'US$50.00');
    expect(Money.format(5050), r'US$50.50');
    expect(Money.format(123456789), r'US$1,234,567.89');
    expect(Money.format(-5050), r'-US$50.50');
    expect(Money.parse('50.50'), 5050);
    expect(Money.parse('50,50'), 5050);
    expect(Money.parse('1,234.56'), 123456);
    expect(Money.parse('1.234,56'), 123456);
    expect(Money.parse('50'), 5000);
    expect(Money.input(5050), '50.50');
    expect(Money.major(5050), '50.50');
  });

  test('Failure: empty or symbol-only input has no amount', () {
    Money.configure(Currency.usd);

    expect(Money.parse(''), isNull);
    expect(Money.parse(r'US$'), isNull);
  });

  test('Security: the currency code falls back to COP', () {
    expect(Currency.fromCode('usd'), Currency.usd);
    expect(Currency.fromCode('EUR'), Currency.cop);
    expect(Currency.fromCode(null), Currency.cop);
  });
}
