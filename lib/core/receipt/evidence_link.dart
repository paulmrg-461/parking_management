import 'package:flutter/foundation.dart';

/// Public page that shows a session's evidence. The plate is the key, so the
/// link is only useful to whoever holds the receipt.
const evidencePath = '/evidence';
const policiesPath = '/policies';

/// Base URL of the deployed app (set with `--dart-define=APP_URL=...`). On web
/// it falls back to the current origin; mobile needs the define to print a
/// reachable link.
const _appUrl = String.fromEnvironment('APP_URL');

Uri? publicEvidenceUri(
  int sessionId, {
  String? base,
}) {
  final raw = (base ?? _appUrl).trim();
  final fallback = raw.isEmpty && kIsWeb ? Uri.base.origin : '';
  final root = raw.isNotEmpty ? raw : fallback;
  if (root.isEmpty) {
    return null;
  }
  final parsed = Uri.parse(root);
  return parsed.replace(
    path: evidencePath,
    queryParameters: {'session': '$sessionId'},
  );
}

/// Printable evidence URL, or null when the app URL is not configured. The
/// plate is intentionally absent: it is the access key the customer types.
String? publicEvidenceUrl(int sessionId, {String? base}) =>
    publicEvidenceUri(sessionId, base: base)?.toString();
