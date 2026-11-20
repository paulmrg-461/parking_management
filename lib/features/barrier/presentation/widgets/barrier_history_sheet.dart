import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../application/barrier_cubit.dart';
import '../../domain/entities/barrier.dart';
import '../../domain/entities/barrier_command.dart';

Future<void> showBarrierHistorySheet(
  BuildContext context,
  Barrier barrier,
  BarrierCubit cubit,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BarrierHistorySheet(barrier: barrier, cubit: cubit),
  );
}

class _BarrierHistorySheet extends StatefulWidget {
  const _BarrierHistorySheet({required this.barrier, required this.cubit});

  final Barrier barrier;
  final BarrierCubit cubit;

  @override
  State<_BarrierHistorySheet> createState() => _BarrierHistorySheetState();
}

class _BarrierHistorySheetState extends State<_BarrierHistorySheet> {
  late final Future<List<BarrierCommand>> _future =
      widget.cubit.history(widget.barrier.deviceId);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.barrierHistory} · ${widget.barrier.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Space.sm),
            Expanded(
              child: FutureBuilder<List<BarrierCommand>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(Space.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final commands = snapshot.data ?? const <BarrierCommand>[];
                  if (commands.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Text(
                        l10n.barrierHistoryEmpty,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: commands.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final command = commands[index];
                      return ListTile(
                        leading: Icon(
                          command.status.succeeded
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                        ),
                        title: Text(
                          l10n.barrierLastCommand(
                            command.source.label(context),
                            MaterialLocalizations.of(context)
                                .formatShortDate(command.issuedAt),
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (command.requestedByName case final name?)
                              name,
                            if (command.reason case final reason?) reason,
                          ].join(' · '),
                        ),
                        trailing: StatusChip(
                          label: command.status.label(context),
                          tone: command.status.succeeded
                              ? StatusTone.success
                              : command.status.isTerminal
                              ? StatusTone.warning
                              : StatusTone.pending,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

extension BarrierSourceLabels on BarrierSource {
  String label(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      BarrierSource.checkin => l10n.barrierSourceCheckin,
      BarrierSource.paidExit => l10n.barrierSourcePaidExit,
      BarrierSource.passRecognised => l10n.barrierSourcePass,
      BarrierSource.manual => l10n.barrierSourceManual,
      BarrierSource.onlinePayment => l10n.barrierSourceOnlinePayment,
    };
  }
}

extension BarrierStatusLabels on BarrierCommandStatus {
  String label(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      BarrierCommandStatus.queued => l10n.barrierStatusQueued,
      BarrierCommandStatus.delivered => l10n.barrierStatusDelivered,
      BarrierCommandStatus.executed => l10n.barrierStatusExecuted,
      BarrierCommandStatus.rejected => l10n.barrierStatusRejected,
      BarrierCommandStatus.expired => l10n.barrierStatusExpired,
      BarrierCommandStatus.cancelled => l10n.barrierStatusExpired,
    };
  }
}
