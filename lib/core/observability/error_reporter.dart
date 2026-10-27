import 'dart:async';

import 'package:flutter/foundation.dart';

import 'client_error_sink.dart';

/// Central place for uncaught errors. Deduplicates and throttles so one broken
/// widget that rebuilds 60 times a second cannot flood the database.
class ErrorReporter {
  ErrorReporter(
    this._sink, {
    DateTime Function()? clock,
    this.minInterval = const Duration(seconds: 30),
    this.enabled = !kDebugMode,
  }) : _clock = clock ?? DateTime.now;

  static const _maxMessage = 2000;
  static const _maxStack = 8000;
  static const _maxFingerprints = 100;

  final ClientErrorSink _sink;
  final DateTime Function() _clock;
  final Duration minInterval;
  final bool enabled;

  final Map<String, DateTime> _lastReported = {};

  Future<void> report(
    Object error,
    StackTrace? stack, {
    Map<String, Object?> context = const {},
  }) async {
    if (!enabled) {
      return;
    }
    final message = _truncate(error.toString(), _maxMessage);
    final fingerprint = '${error.runtimeType}:$message';
    final now = _clock();
    final last = _lastReported[fingerprint];
    if (last != null && now.difference(last) < minInterval) {
      return;
    }
    if (_lastReported.length >= _maxFingerprints) {
      _lastReported.clear();
    }
    _lastReported[fingerprint] = now;

    try {
      await _sink.send(
        platform: _platform,
        message: message,
        stack: stack == null ? null : _truncate(stack.toString(), _maxStack),
        context: context,
      );
    } catch (_) {
      // Reporting is best effort; swallow transport errors.
    }
  }

  String get _platform {
    if (kIsWeb) {
      return 'web';
    }
    return defaultTargetPlatform.name.toLowerCase();
  }

  String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
