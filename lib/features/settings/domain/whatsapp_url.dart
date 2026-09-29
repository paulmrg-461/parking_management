/// Builds the WhatsApp deep link for [raw] (e.g. `+57 300 111 2233`), or
/// `null` when it contains no digits. Only digits reach the URL, so `+`
/// signs, spaces and separators never leak into the link.
String? whatsappUrl(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? null : 'https://wa.me/$digits';
}
