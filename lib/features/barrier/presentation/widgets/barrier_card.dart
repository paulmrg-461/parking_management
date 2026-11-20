import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/date_time_text.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../devices/domain/entities/lot_device.dart';
import '../../domain/entities/barrier.dart';
import '../../domain/entities/barrier_command.dart';

class BarrierCard extends StatelessWidget {
  const BarrierCard({
    super.key,
    required this.barrier,
    required this.onOpen,
    required this.onHistory,
    this.onConfig,
  });

  final Barrier barrier;
  final VoidCallback? onOpen;
  final VoidCallback onHistory;
  final VoidCallback? onConfig;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final last = barrier.lastCommand;
    return Card(
      key: Key('barrier_${barrier.deviceId}'),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    barrier.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                StatusChip(
                  label: _statusLabel(context),
                  tone: barrier.online
                      ? StatusTone.success
                      : StatusTone.neutral,
                  icon: barrier.online
                      ? Icons.circle
                      : Icons.cloud_off_outlined,
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Row(
              children: [
                Icon(
                  barrier.direction == BarrierDirection.entry
                      ? Icons.login
                      : Icons.logout,
                  size: Space.md,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Space.xs),
                Text(
                  barrier.direction == BarrierDirection.entry
                      ? l10n.barrierDirectionEntry
                      : l10n.barrierDirectionExit,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (!barrier.online) ...[
              const SizedBox(height: Space.xs),
              Text(
                l10n.barrierOffline,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (last != null) ...[
              const SizedBox(height: Space.xs),
              Text(
                l10n.barrierLastCommand(
                  _sourceLabel(l10n, last.source),
                  _when(context, last.issuedAt),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: Space.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: Key('barrier_history_${barrier.deviceId}'),
                  tooltip: l10n.barrierHistory,
                  onPressed: onHistory,
                  icon: const Icon(Icons.history),
                ),
                if (onConfig case final config?)
                  IconButton(
                    key: Key('barrier_config_${barrier.deviceId}'),
                    tooltip: l10n.barrierConfigTitle,
                    onPressed: config,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                const SizedBox(width: Space.xs),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    key: Key('barrier_open_${barrier.deviceId}'),
                    onPressed: barrier.online ? onOpen : null,
                    icon: const Icon(Icons.lock_open),
                    label: Text(l10n.barrierOpen),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (barrier.status) {
      DeviceStatus.online => l10n.devicesStatusOnline,
      DeviceStatus.offline => l10n.devicesStatusOffline,
      DeviceStatus.disabled => l10n.devicesStatusDisabled,
      DeviceStatus.neverSeen => l10n.devicesStatusNeverSeen,
    };
  }

  String _sourceLabel(AppLocalizations l10n, BarrierSource source) =>
      switch (source) {
        BarrierSource.checkin => l10n.barrierSourceCheckin,
        BarrierSource.paidExit => l10n.barrierSourcePaidExit,
        BarrierSource.passRecognised => l10n.barrierSourcePass,
        BarrierSource.manual => l10n.barrierSourceManual,
        BarrierSource.onlinePayment => l10n.barrierSourceOnlinePayment,
      };

  String _when(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(value);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: true,
    );
    return '$date $time';
  }
}
