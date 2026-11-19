import 'package:flutter/foundation.dart';

/// Public base URL of the deployed app (`--dart-define=APP_URL=...`). On web it
/// falls back to the current origin; mobile needs the define.
const _appUrl = String.fromEnvironment('APP_URL');

Uri? appBaseUri() {
  final raw = _appUrl.trim();
  final fallback = raw.isEmpty && kIsWeb ? Uri.base.origin : '';
  final root = raw.isNotEmpty ? raw : fallback;
  if (root.isEmpty) {
    return null;
  }
  final parsed = Uri.tryParse(root);
  return parsed;
}
