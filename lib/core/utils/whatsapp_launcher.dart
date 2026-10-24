import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../widgets/submission_feedback.dart';

/// Opens a `wa.me` link. A device without WhatsApp shows a snack instead of
/// crashing the screen.
Future<void> openWhatsapp(BuildContext context, String? url) async {
  if (url == null) {
    return;
  }
  try {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      showErrorSnack(context, context.l10n.errorWhatsappUnavailable);
    }
  } catch (_) {
    if (context.mounted) {
      showErrorSnack(context, context.l10n.errorWhatsappUnavailable);
    }
  }
}
