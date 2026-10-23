import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/payment_method.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/vehicle_history_cubit.dart';
import '../domain/entities/vehicle_history.dart';

class VehicleHistoryPage extends StatefulWidget {
  const VehicleHistoryPage({super.key, this.initialPlate});

  final String? initialPlate;

  @override
  State<VehicleHistoryPage> createState() => _VehicleHistoryPageState();
}

class _VehicleHistoryPageState extends State<VehicleHistoryPage> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final plate = widget.initialPlate?.trim();
    if (plate != null && plate.isNotEmpty) {
      _controller.text = plate;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<VehicleHistoryCubit>().search(plate);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final plate = _controller.text.trim();
    if (plate.isNotEmpty) {
      context.read<VehicleHistoryCubit>().search(plate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleHistoryTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: l10n.plateLabel,
                hintText: l10n.plateHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: l10n.actionConfirm,
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<VehicleHistoryCubit, VehicleHistoryState>(
              builder: (context, state) => switch (state.status) {
                VehicleHistoryStatus.initial => _Hint(
                  message: l10n.vehicleHistoryPrompt,
                ),
                VehicleHistoryStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                VehicleHistoryStatus.failure => ErrorState(
                  message: state.failure == null
                      ? l10n.errorUnknown
                      : l10n.failure(state.failure!),
                  onRetry: _search,
                ),
                VehicleHistoryStatus.loaded => _HistoryBody(
                  history: state.history!,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: Space.xxl,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.history});

  final VehicleHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final details = [
      history.categoryName,
      if (history.color != null && history.color!.isNotEmpty) history.color!,
      if (history.brand != null && history.brand!.isNotEmpty) history.brand!,
    ].join(' · ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        0,
        Space.md,
        Space.lg,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(history.plate, style: textTheme.headlineSmall),
                    const Spacer(),
                    if (history.openSessions > 0)
                      StatusChip(
                        label: l10n.statusOpen,
                        tone: StatusTone.warning,
                      ),
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: Space.xs),
                  Text(details, style: textTheme.bodyMedium),
                ],
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: l10n.vehicleHistoryVisits,
                        value: '${history.visits}',
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.vehicleHistoryTotalSpent,
                            style: textTheme.labelMedium,
                          ),
                          MoneyText(
                            history.totalSpent,
                            style: textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(l10n.vehicleHistorySessions, style: textTheme.titleMedium),
        const SizedBox(height: Space.sm),
        if (history.sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Text(l10n.vehicleHistoryNoSessions),
          )
        else
          for (final session in history.sessions)
            _SessionTile(session: session),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium),
        Text(value, style: textTheme.titleLarge),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final VehicleHistorySession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final duration = Formatters.duration(
      l10n,
      Duration(seconds: session.durationSeconds),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Formatters.dateTime(session.entryTime),
                    style: textTheme.titleSmall,
                  ),
                ),
                StatusChip(
                  label: session.isOpen ? l10n.statusOpen : l10n.statusClosed,
                  tone: session.isOpen
                      ? StatusTone.warning
                      : StatusTone.success,
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              session.exitTime == null
                  ? '${l10n.vehicleHistoryDuration(duration)} · ${l10n.vehicleHistoryOpen}'
                  : '${Formatters.dateTime(session.exitTime!)} · ${l10n.vehicleHistoryDuration(duration)}',
              style: textTheme.bodySmall,
            ),
            if (session.amountCharged != null) ...[
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  MoneyText(
                    session.amountCharged!,
                    style: textTheme.titleMedium,
                  ),
                  if (session.paymentMethod != null) ...[
                    const SizedBox(width: Space.sm),
                    Text(
                      paymentMethodLabel(l10n, session.paymentMethod),
                      style: textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                  if (session.ticketNumber != null)
                    Text(
                      session.ticketNumber!,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
