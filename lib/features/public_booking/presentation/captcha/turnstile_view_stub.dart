import 'package:flutter/widgets.dart';

import 'captcha_request.dart';

/// Turnstile is a browser widget: mobile and desktop targets have none, so the
/// booking form skips the captcha there.
const bool turnstileSupported = false;

Widget buildTurnstile(BuildContext context, CaptchaRequest request) =>
    const SizedBox.shrink();
