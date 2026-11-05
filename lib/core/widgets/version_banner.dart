import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/settings/application/branding_cubit.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import '../version/app_version.dart';

/// Site-level minimum-version guard: kiosk/tablet installs older than
/// `parking_settings.min_app_version` get a persistent, localized warning
/// instead of silent contract mismatches.
class VersionBanner extends StatelessWidget {
  const VersionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    BrandingCubit? branding;
    try {
      branding = context.watch<BrandingCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final minimum = branding.state.settingsOrNull?.minAppVersion ?? '';
    if (!isVersionOutdated(appVersion, minimum)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        color: scheme.errorContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.system_update_alt,
              color: scheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                context.l10n.updateRequired(appVersion, minimum),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
