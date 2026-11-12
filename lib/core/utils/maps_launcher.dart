import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../widgets/submission_feedback.dart';

/// Google Maps search for [address] (`https://www.google.com/maps/search/?api=1`).
/// Returns null when there is no address to point at.
Uri? mapsUrl(String? address) {
  final cleaned = (address ?? '').trim();
  if (cleaned.isEmpty) {
    return null;
  }
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': cleaned,
  });
}

/// Opens [address] in the device's maps app (or the browser). A device with
/// neither shows a snack instead of throwing at the caller.
Future<void> openMaps(BuildContext context, String? address) async {
  final url = mapsUrl(address);
  if (url == null) {
    return;
  }
  try {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showErrorSnack(context, context.l10n.errorMapsUnavailable);
    }
  } catch (_) {
    if (context.mounted) {
      showErrorSnack(context, context.l10n.errorMapsUnavailable);
    }
  }
}
