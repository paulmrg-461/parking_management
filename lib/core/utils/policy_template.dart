/// Replaces the placeholders of the legal policy template with the site's
/// identity. Unknown placeholders stay untouched so an admin can see typos.
String renderPolicyTemplate(
  String template, {
  required String parking,
  required String address,
  required String schedule,
  required String phone,
}) {
  var text = template;
  final values = {
    '{{parking}}': parking,
    '{{address}}': address,
    '{{schedule}}': schedule,
    '{{phone}}': phone,
  };
  for (final entry in values.entries) {
    text = text.replaceAll(entry.key, entry.value.trim());
  }
  return text;
}
