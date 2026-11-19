import 'package:flutter/foundation.dart';

/// Public survey page. The session and the plate travel in the link because the
/// receipt already carries both (the plate is the access key, as on
/// `/evidence`).
const feedbackPath = '/feedback';

/// Base URL of the deployed app (set with `--dart-define=APP_URL=...`). On web
/// it falls back to the current origin; mobile needs the define to print a
/// reachable link.
const _appUrl = String.fromEnvironment('APP_URL');

Uri? publicFeedbackUri(int sessionId, {required String plate, String? base}) {
  if (sessionId <= 0) {
    return null;
  }
  final raw = (base ?? _appUrl).trim();
  final fallback = raw.isEmpty && kIsWeb ? Uri.base.origin : '';
  final root = raw.isNotEmpty ? raw : fallback;
  if (root.isEmpty) {
    return null;
  }
  final normalized = plate.trim().toUpperCase();
  return Uri.parse(root).replace(
    path: feedbackPath,
    queryParameters: {
      'session': '$sessionId',
      if (normalized.isNotEmpty) 'plate': normalized,
    },
  );
}

/// Printable survey URL, or null when the app URL is not configured.
String? publicFeedbackUrl(
  int sessionId, {
  required String plate,
  String? base,
}) => publicFeedbackUri(sessionId, plate: plate, base: base)?.toString();
