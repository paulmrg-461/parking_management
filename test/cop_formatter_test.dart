import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/utils/cop_formatter.dart';

void main() {
  group('CopFormatter.format', () {
    test('formats a whole COP amount with grouping and no decimals', () {
      final result = CopFormatter.format(5000);

      expect(result, contains('5.000'));
      expect(result, startsWith(r'$'));
    });

    test('formats zero and large amounts without grouping errors', () {
      expect(CopFormatter.format(0), contains('0'));
      expect(CopFormatter.format(1000000), contains('1.000.000'));
    });
  });

  group('CopFormatter.parse', () {
    test('parses a formatted COP string back to an integer', () {
      expect(CopFormatter.parse(r'$5.000'), 5000);
    });

    test('returns null for non-numeric input', () {
      expect(CopFormatter.parse('abc'), isNull);
      expect(CopFormatter.parse(''), isNull);
    });

    test('ignores symbols, spaces, and separators when parsing', () {
      expect(CopFormatter.parse(r'$ 1.234.567 '), 1234567);
    });
  });
}
