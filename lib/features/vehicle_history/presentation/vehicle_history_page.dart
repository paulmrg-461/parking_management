import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/payment_method.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/entities/user.dart';
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

  bool _canManage(BuildContext context) {
    try {
      final auth = context.read<AuthCubit>();
      return switch (auth.state) {
        AuthAuthenticated(:final session) =>
          session.user.role == UserRole.admin,
        _ => false,
      };
    } on ProviderNotFoundException {
      return false;
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
            child: BlocListener<VehicleHistoryCubit, VehicleHistoryState>(
              listenWhen: (previous, current) =>
                  previous.failure != current.failure &&
                  current.failure != null,
              listener: (context, state) {
                final failure = state.failure!;
                showErrorSnack(context, context.l10n.failure(failure));
                context.read<VehicleHistoryCubit>().clearFailure();
              },
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
                  key: ValueKey(state.history!.plate),
                  history: state.history!,
                  canManage: _canManage(context),
                ),
              },
            ),
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

class _HistoryBody extends StatefulWidget {
  const _HistoryBody({
    super.key,
    required this.history,
    required this.canManage,
  });

  final VehicleHistory history;
  final bool canManage;

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  int? _lotFilter;

  VehicleHistory get history => widget.history;
  bool get canManage => widget.canManage;

  List<VehicleHistorySession> get _sessions => _lotFilter == null
      ? history.sessions
      : [
          for (final session in history.sessions)
            if (session.lotId == _lotFilter) session,
        ];

  Future<void> _editNotes(BuildContext context) async {
    final notes = await showDialog<String>(
      context: context,
      builder: (_) => _NotesDialog(initial: history.notes ?? ''),
    );
    if (notes != null && context.mounted) {
      await context.read<VehicleHistoryCubit>().updateFlags(notes: notes);
    }
  }

  Future<void> _toggleBlacklist(BuildContext context) async {
    final l10n = context.l10n;
    final blocking = !history.isBlacklisted;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: blocking ? l10n.vehicleBlacklistTitle : l10n.vehicleUnblockTitle,
        body: blocking
            ? l10n.vehicleBlacklistBody(history.plate)
            : l10n.vehicleUnblockBody(history.plate),
        confirmLabel: blocking ? l10n.vehicleBlacklist : l10n.vehicleUnblock,
        destructive: blocking,
      ),
    );
    if (confirmed && context.mounted) {
      await context.read<VehicleHistoryCubit>().updateFlags(
        blacklisted: blocking,
      );
    }
  }

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
                    if (history.isBlacklisted) ...[
                      const SizedBox(width: Space.xs),
                      StatusChip(
                        label: l10n.vehicleBlacklisted,
                        tone: StatusTone.warning,
                        icon: Icons.block,
                      ),
                    ],
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
        if (history.notes != null && history.notes!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.vehicleNotes, style: textTheme.labelMedium),
                    const SizedBox(height: Space.xs),
                    Text(history.notes!),
                  ],
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: Space.sm,
            children: [
              TextButton.icon(
                onPressed: () => _editNotes(context),
                icon: const Icon(Icons.notes_outlined),
                label: Text(
                  history.notes == null || history.notes!.isEmpty
                      ? l10n.vehicleAddNotes
                      : l10n.vehicleEditNotes,
                ),
              ),
              if (canManage)
                TextButton.icon(
                  onPressed: () => _toggleBlacklist(context),
                  icon: Icon(
                    history.isBlacklisted ? Icons.lock_open : Icons.block,
                  ),
                  label: Text(
                    history.isBlacklisted
                        ? l10n.vehicleUnblock
                        : l10n.vehicleBlacklist,
                  ),
                ),
            ],
          ),
        ),
        if (history.lots.length > 1 &&
            history.currentLotVisits > 0) ...[
          const SizedBox(height: Space.sm),
          Text(
            l10n.vehicleHistoryCurrentLotVisits(history.currentLotVisits),
            style: textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.vehicleHistorySessions,
                style: textTheme.titleMedium,
              ),
            ),
            if (history.lots.length > 1)
              DropdownButton<int?>(
                value: _lotFilter,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.vehicleHistoryAllLots),
                  ),
                  for (final lot in history.lots)
                    DropdownMenuItem(
                      value: lot.id,
                      child: Text(lot.name),
                    ),
                ],
                onChanged: (value) => setState(() => _lotFilter = value),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        if (history.sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Text(l10n.vehicleHistoryNoSessions),
          )
        else if (_sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Text(l10n.vehicleHistoryNoSessions),
          )
        else
          for (final session in _sessions) _SessionTile(session: session),
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
                if (session.lotName != null) ...[
                  StatusChip(
                    label: session.lotName!,
                    tone: StatusTone.neutral,
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(width: Space.xs),
                ],
                if (session.lostTicket) ...[
                  StatusChip(
                    label: l10n.lostTicket,
                    tone: StatusTone.warning,
                    icon: Icons.confirmation_number_outlined,
                  ),
                  const SizedBox(width: Space.xs),
                ],
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


class _NotesDialog extends StatefulWidget {
  const _NotesDialog({required this.initial});

  final String initial;

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.vehicleNotes),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: context.l10n.vehicleNotesHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(context.l10n.actionSave),
        ),
      ],
    );
  }
}
