import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/utils/formatters.dart';

void main() {
  test('Success: PDF ranges use the ASCII separator Helvetica supports', () {
    final text = Formatters.pdfDateRange(
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 31),
    );

    expect(text, contains(' - '));
    expect(text, isNot(contains('—')));
    expect(text, isNot(contains('–')));
  });
}
