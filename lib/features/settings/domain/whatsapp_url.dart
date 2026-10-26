/// Builds the WhatsApp deep link for [raw] (e.g. `+57 300 111 2233`), or
/// `null` when it contains no digits. Only digits reach the URL, so `+`
/// signs, spaces and separators never leak into the link. [text] is prefilled
/// in the chat when provided.
String? whatsappUrl(String raw, {String? text}) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return null;
  }
  final message = text?.trim() ?? '';
  return message.isEmpty
      ? 'https://wa.me/$digits'
      : 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}';
}
