import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/entities/user.dart';
import '../../settings/application/branding_cubit.dart';
import '../../settings/domain/entities/parking_settings.dart';

/// National emergency line used when the site has not configured a quadrant.
const emergencyFallbackPhone = '123';

/// Opens the emergency panel with the site's nearest police quadrant.
Future<void> showEmergencyDialog(BuildContext context) {
  final settings = _settings(context);
  final configured = settings?.policePhone.trim() ?? '';
  return showDialog<void>(
    context: context,
    builder: (_) => EmergencyDialog(
      policePhone: configured,
      siteName: settings?.name.trim() ?? '',
      siteAddress: settings?.address.trim() ?? '',
      canConfigure: _isAdmin(context),
      onConfigure: () => context.go('/settings'),
    ),
  );
}

ParkingSettings? _settings(BuildContext context) {
  try {
    return context.read<BrandingCubit>().state.settingsOrNull;
  } on ProviderNotFoundException {
    return null;
  }
}

bool _isAdmin(BuildContext context) {
  try {
    return switch (context.read<AuthCubit>().state) {
      AuthAuthenticated(:final session) => session.user.role == UserRole.admin,
      _ => false,
    };
  } on ProviderNotFoundException {
    return false;
  }
}

/// Emergency caller: shows the location to report, the quadrant number and a
/// single large call action. Works before configuration by falling back to
/// [emergencyFallbackPhone].
class EmergencyDialog extends StatelessWidget {
  const EmergencyDialog({
    super.key,
    required this.policePhone,
    this.siteName = '',
    this.siteAddress = '',
    this.canConfigure = false,
    this.onConfigure,
    this.onCall,
  });

  final String policePhone;
  final String siteName;
  final String siteAddress;
  final bool canConfigure;
  final VoidCallback? onConfigure;

  /// Test seam: replaces the platform dialer. Returns whether it opened.
  final Future<bool> Function(String phone)? onCall;

  bool get _configured => policePhone.trim().isNotEmpty;

  String get _number =>
      _configured ? policePhone.trim() : emergencyFallbackPhone;

  Future<void> _call(BuildContext context) async {
    final digits = _number.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) {
      return;
    }
    try {
      final opened = await (onCall ?? _launchTel)(digits);
      if (!opened && context.mounted) {
        showErrorSnack(context, context.l10n.emergencyCallFailed);
      }
    } catch (_) {
      if (context.mounted) {
        showErrorSnack(context, context.l10n.emergencyCallFailed);
      }
    }
  }

  Future<bool> _launchTel(String phone) => launchUrl(Uri.parse('tel:$phone'));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final location = [
      if (siteName.isNotEmpty) siteName,
      if (siteAddress.isNotEmpty) siteAddress,
    ].join('\n');
    return AlertDialog(
      icon: Icon(Icons.local_police, size: 36, color: scheme.error),
      title: Text(l10n.emergencyTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.emergencyBody, style: textTheme.bodyMedium),
            if (location.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        l10n.emergencyLocation(location),
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Space.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Column(
                children: [
                  Text(
                    _configured
                        ? l10n.emergencyNumberLabel
                        : l10n.emergencyDefaultLabel,
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    _number,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (!_configured) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      l10n.emergencyDefaultHint,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                key: const Key('emergency_call'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: () => _call(context),
                icon: const Icon(Icons.call),
                label: Text(
                  _configured
                      ? l10n.emergencyCallNow
                      : l10n.emergencyCallDefault(_number),
                ),
              ),
            ),
            if (!_configured && canConfigure) ...[
              const SizedBox(height: Space.sm),
              TextButton.icon(
                key: const Key('emergency_configure'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfigure?.call();
                },
                icon: const Icon(Icons.settings_outlined),
                label: Text(l10n.emergencyGoToSettings),
              ),
            ] else if (!_configured) ...[
              const SizedBox(height: Space.sm),
              Text(
                l10n.emergencyAskAdmin,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}
