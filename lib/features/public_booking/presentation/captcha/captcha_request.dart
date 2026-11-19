import 'package:flutter/widgets.dart';

/// What the booking form hands to a captcha widget: the public site key and
/// the three outcomes it has to report back.
class CaptchaRequest {
  const CaptchaRequest({
    required this.siteKey,
    required this.onToken,
    required this.onExpired,
    required this.onError,
  });

  final String siteKey;

  /// The customer passed the challenge; the token is single use.
  final ValueChanged<String> onToken;

  /// The token (or an interactive challenge) timed out before it was used.
  final VoidCallback onExpired;

  /// The widget could not load or the challenge failed.
  final VoidCallback onError;
}

/// Renders a captcha for [request]. The page injects it so widget tests can
/// stand in for the browser-only Turnstile iframe.
typedef CaptchaBuilder = Widget Function(
  BuildContext context,
  CaptchaRequest request,
);
