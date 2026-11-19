import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import 'emergency_dialog.dart';

/// AppBar action: always-reachable emergency call. Kept visually distinct so
/// an operator can find it without reading the menu.
class EmergencyAction extends StatelessWidget {
  const EmergencyAction({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      key: const Key('emergency_action'),
      tooltip: context.l10n.emergencyTitle,
      style: IconButton.styleFrom(
        backgroundColor: scheme.errorContainer,
        foregroundColor: scheme.onErrorContainer,
      ),
      onPressed: () => showEmergencyDialog(context),
      icon: const Icon(Icons.local_police_outlined),
    );
  }
}

/// Highlighted emergency entry for the phone drawer.
class EmergencyDrawerTile extends StatelessWidget {
  const EmergencyDrawerTile({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
      child: Material(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(Radii.md),
        child: ListTile(
          key: const Key('emergency_drawer_tile'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          leading: Icon(
            Icons.local_police_outlined,
            color: scheme.onErrorContainer,
          ),
          title: Text(
            l10n.emergencyTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            l10n.emergencyDrawerHint,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onErrorContainer),
          ),
          trailing: Icon(Icons.call, color: scheme.onErrorContainer),
          onTap: onTap ?? () => showEmergencyDialog(context),
        ),
      ),
    );
  }
}
