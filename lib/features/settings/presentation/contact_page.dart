import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/branding_cubit.dart';
import '../domain/entities/parking_settings.dart';
import '../domain/whatsapp_url.dart';

/// Read-only contact card for the parking identity (admin and operator).
class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<BrandingCubit, BrandingState>(
      builder: (context, branding) {
        final settings = branding.settingsOrNull ?? ParkingSettings.defaults();
        final configured = settings != ParkingSettings.defaults();
        return ListPageScaffold(
          title: l10n.contactTitle,
          onRefresh: () => context.read<BrandingCubit>().load(),
          body: ListView(
            padding: const EdgeInsets.all(Space.md),
            children: [
              _header(context, branding, settings, configured),
              if (settings.address.isNotEmpty)
                _row(
                  context,
                  Icons.place_outlined,
                  l10n.settingsAddress,
                  settings.address,
                ),
              if (settings.schedule.isNotEmpty)
                _row(
                  context,
                  Icons.schedule_outlined,
                  l10n.settingsSchedule,
                  settings.schedule,
                ),
              if (settings.phone.isNotEmpty)
                _row(
                  context,
                  Icons.phone_outlined,
                  l10n.settingsPhone,
                  settings.phone,
                  onTap: () => _dial(context, settings.phone),
                ),
              if (settings.website.isNotEmpty)
                _row(
                  context,
                  Icons.language_outlined,
                  l10n.settingsWebsite,
                  settings.website,
                  onTap: () => _openWebsite(context, settings.website),
                ),
              if (whatsappUrl(settings.whatsapp) case final url?)
                _row(
                  context,
                  Icons.chat_outlined,
                  l10n.contactWhatsApp,
                  settings.whatsapp,
                  onTap: () => _launch(context, Uri.parse(url)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(
    BuildContext context,
    BrandingState branding,
    ParkingSettings settings,
    bool configured,
  ) {
    final l10n = context.l10n;
    final bytes = branding.logoOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Row(
        children: [
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(Space.xs),
              child: Image.memory(
                bytes,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.local_parking_rounded, size: 72),
              ),
            )
          else
            const Icon(Icons.local_parking_rounded, size: 72),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              configured ? settings.name : l10n.appTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(value),
    onTap: onTap,
  );

  Future<void> _dial(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'\s'), '');
    await _launch(context, Uri.parse('tel:$digits'));
  }

  Future<void> _openWebsite(BuildContext context, String website) async {
    final text = website.trim();
    final url = text.startsWith('http') ? text : 'https://$text';
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await _launch(context, uri);
    }
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
      return;
    }
    if (context.mounted) {
      showErrorSnack(context, context.l10n.errorUnknown);
    }
  }
}
