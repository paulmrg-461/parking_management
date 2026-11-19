/// Colombian mobile numbers: 10 digits starting with 3, with an optional `+57`
/// country code. The public booking page and `public_create_reservation` share
/// this rule, and the number is stored in the local 10-digit form so the
/// per-phone guard keeps counting a customer once.
String? normalizeMobilePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final local = digits.length == 12 && digits.startsWith('57')
      ? digits.substring(2)
      : digits;
  return RegExp(r'^3\d{9}$').hasMatch(local) ? local : null;
}
