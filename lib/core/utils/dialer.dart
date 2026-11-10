import 'package:url_launcher/url_launcher.dart';

/// Opens the device dialer with [phone]. A device without a dialer (desktop,
/// a browser tab, the headless web build) simply does nothing instead of
/// throwing at the caller.
Future<void> openDialer(String? phone) async {
  final digits = (phone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) {
    return;
  }
  try {
    await launchUrl(Uri.parse('tel:$digits'));
  } catch (_) {
    // Nothing to open: keep the screen usable.
  }
}
