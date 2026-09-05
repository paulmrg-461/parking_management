import 'package:intl/intl.dart';

class CopFormatter {
  CopFormatter._();

  static final NumberFormat _plain = NumberFormat('#,##0', 'es_CO');

  static String format(int amount) => '\$${_plain.format(amount)}';

  static int? parse(String value) {
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return null;
    }
    return int.tryParse(digits);
  }
}
