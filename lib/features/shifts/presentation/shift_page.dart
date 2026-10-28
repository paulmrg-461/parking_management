import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_input.dart';
import '../../../core/receipt/pdf_share.dart';
import '../../../core/network/connectivity_cubit.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../lots/application/lots_cubit.dart';
import '../application/shift_cubit.dart';
import '../domain/entities/shift_summary.dart';
import 'shift_pdf.dart';
import 'widgets/cash_count_sheet.dart';

class ShiftPage extends StatefulWidget {
  const ShiftPage({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<ShiftPage> createState() => _ShiftPageState();
}

String? _activeLotName(BuildContext context) {
  try {
    final state = context.read<LotsCubit>().state;
    if (state is LotsLoaded) {
      return state.active?.name;
    }
  } on ProviderNotFoundException {
    // Isolated tests do not provide the lot cubit.
  }
  return null;
}

class _ShiftPageState extends State<ShiftPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<ShiftCubit>();
      if (cubit.state.status == ShiftStatus.initial) {
        cubit.load(admin: widget.isAdmin);
      }
    });
  }

  /// Cash actions are silent otherwise; confirm them in text and to screen
  /// readers so the operator knows the shift really changed.
  void _confirmSuccess(BuildContext context, ShiftAction? action) {
    final l10n = context.l10n;
    final message = switch (action) {
      ShiftAction.opened => l10n.shiftOpenedDone,
      ShiftAction.closed => l10n.shiftClosedDone,
      ShiftAction.movement => l10n.shiftMovementDone,
      ShiftAction.adjusted => l10n.shiftAdjustedDone,
      null => null,
    };
    if (message == null) {
      return;
    }
    SemanticsService.announce(message, Directionality.of(context));
    showInfoSnack(context, message);
  }

  bool _online(BuildContext context) {
    try {
      return context.watch<ConnectivityCubit>().state;
    } on ProviderNotFoundException {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final online = _online(context);
    return BlocListener<ShiftCubit, ShiftState>(
      listenWhen: (previous, current) =>
          submissionJustFailed(previous.submission, current.submission) ||
          submissionJustSucceeded(previous.submission, current.submission),
      listener: (context, state) {
        switch (state.submission) {
          case SubmissionFailed(:final message, :final failure):
            showErrorSnack(context, l10n.errorText(message, failure));
          case SubmissionSucceeded():
            _confirmSuccess(context, state.lastAction);
          default:
            break;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.shiftTitle),
          actions: [
            IconButton(
              tooltip: l10n.actionRetry,
              onPressed: () =>
                  context.read<ShiftCubit>().load(admin: widget.isAdmin),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: BlocBuilder<ShiftCubit, ShiftState>(
          builder: (context, state) => switch (state.status) {
            ShiftStatus.initial || ShiftStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            ShiftStatus.failure => ErrorState(
              message: state.error == null
                  ? l10n.errorUnknown
                  : l10n.failure(state.error!),
              onRetry: () =>
                  context.read<ShiftCubit>().load(admin: widget.isAdmin),
            ),
            ShiftStatus.loaded => _Content(
              state: state,
              isAdmin: widget.isAdmin,
              online: online,
            ),
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.isAdmin,
    required this.online,
  });

  final ShiftState state;
  final bool isAdmin;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = state.current;
    return RefreshIndicator(
      onRefresh: () => context.read<ShiftCubit>().load(admin: isAdmin),
      child: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
        if (!online) const _OfflineNotice(),
        if (current != null)
          _OpenShiftCard(shift: current, online: online)
        else ...[
          _OpenShiftForm(online: online),
          if (state.lastClosed != null) ...[
            const SizedBox(height: Space.lg),
            _ClosedShiftCard(shift: state.lastClosed!),
          ],
        ],
        if (isAdmin) ...[
          const SizedBox(height: Space.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.shiftHistory,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (state.historyFrom != null || state.historyTo != null)
                TextButton(
                  onPressed: () => context.read<ShiftCubit>().load(
                    admin: true,
                    clearHistoryRange: true,
                  ),
                  child: Text(l10n.shiftHistoryClearFilter),
                ),
              IconButton(
                tooltip: l10n.shiftHistoryFilter,
                onPressed: () => _pickHistoryRange(context, state),
                icon: const Icon(Icons.date_range),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (state.history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Text(l10n.shiftHistoryEmpty),
            )
          else
            for (final shift in state.history) _HistoryTile(shift: shift),
        ],
        ],
      ),
    );
  }

  Future<void> _pickHistoryRange(BuildContext context, ShiftState state) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: state.historyFrom == null || state.historyTo == null
          ? null
          : DateTimeRange(
              start: state.historyFrom!,
              end: state.historyTo!,
            ),
    );
    if (picked != null && context.mounted) {
      await context.read<ShiftCubit>().load(
        admin: true,
        historyFrom: picked.start,
        historyTo: picked.end,
      );
    }
  }
}

Future<void> exportShiftPdf(BuildContext context, ShiftSummary shift) async {
  final bytes = await buildShiftPdf(
    l10n: context.l10n,
    shift: shift,
    lotName: _activeLotName(context),
  );
  if (!context.mounted) {
    return;
  }
  await sharePdfBytes(
    context,
    bytes: bytes,
    filename: pdfFileName('turno-${shift.id}', shift.openedAt),
  );
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: scheme.onErrorContainer),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                context.l10n.shiftOffline,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenShiftForm extends StatefulWidget {
  const _OpenShiftForm({required this.online});

  final bool online;

  @override
  State<_OpenShiftForm> createState() => _OpenShiftFormState();
}

class _OpenShiftFormState extends State<_OpenShiftForm> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController(text: '0');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<ShiftCubit>().open(Money.parse(_controller.text.trim()) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.shiftNoOpen,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: moneyInputFormatters(),
                decoration: InputDecoration(
                  labelText: l10n.shiftOpeningFloat,
                ),
                validator: (value) {
                  final amount = Money.parse(value);
                  return amount == null || amount < 0
                      ? l10n.invalidAmount
                      : null;
                },
              ),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                onPressed: widget.online ? _open : null,
                icon: const Icon(Icons.lock_open),
                label: Text(l10n.shiftOpen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenShiftCard extends StatelessWidget {
  const _OpenShiftCard({required this.shift, required this.online});

  final ShiftSummary shift;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shiftOpenTitle, style: textTheme.titleMedium),
            Text(
              l10n.shiftOpenedAt(Formatters.dateTimeFull(shift.openedAt)),
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: Space.md),
            _MetricRow(label: l10n.shiftOpeningFloat, amount: shift.openingFloat),
            _MetricRow(label: l10n.shiftSales, amount: shift.revenue),
            _MetricRow(label: l10n.shiftCashSales, amount: shift.cashSales),
            _MetricRow(label: l10n.shiftPassPayments, amount: shift.passPayments),
            _MetricRow(
              label: l10n.shiftPassCash,
              amount: shift.passCashSales,
            ),
            _MetricRow(label: l10n.shiftWithdrawals, amount: shift.withdrawals),
            _MetricRow(label: l10n.shiftDeposits, amount: shift.deposits),
            _MetricRow(label: l10n.shiftDiscounts, amount: shift.discounts),
            const Divider(),
            _MetricRow(
              label: l10n.shiftExpectedCash,
              amount: shift.expectedCash,
              bold: true,
            ),
            _MetricRow(
              label: l10n.shiftSessions,
              amount: shift.sessionCount,
              money: false,
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: online ? () => _movement(context, 'withdrawal') : null,
                  icon: const Icon(Icons.remove),
                  label: Text(l10n.shiftWithdraw),
                ),
                OutlinedButton.icon(
                  onPressed: online ? () => _movement(context, 'deposit') : null,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.shiftDeposit),
                ),
                FilledButton.icon(
                  onPressed: online ? () => _close(context) : null,
                  icon: const Icon(Icons.lock),
                  label: Text(l10n.shiftClose),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _movement(BuildContext context, String type) async {
    final result = await showDialog<_MovementResult>(
      context: context,
      builder: (_) => _CashMovementDialog(type: type),
    );
    if (result != null && context.mounted) {
      await context.read<ShiftCubit>().addMovement(
        type: type,
        amount: result.amount,
        reason: result.reason,
      );
    }
  }

  Future<void> _close(BuildContext context) async {
    final l10n = context.l10n;
    final result = await showDialog<_CloseResult>(
      context: context,
      builder: (_) => _CloseShiftDialog(expected: shift.expectedCash),
    );
    if (result == null || !context.mounted) {
      return;
    }
    final difference = result.counted - shift.expectedCash;
    if (difference != 0) {
      // Closing with a mismatch is legitimate (tips, mistakes) but never
      // accidental.
      final confirmed = await ConfirmDialog.show(
        context,
        ConfirmDialog(
          title: l10n.shiftDifferenceConfirmTitle,
          body: l10n.shiftDifferenceConfirmBody(Formatters.money(difference)),
          confirmLabel: l10n.shiftClose,
          destructive: true,
        ),
      );
      if (!confirmed || !context.mounted) {
        return;
      }
    }
    await context.read<ShiftCubit>().closeShift(
      countedCash: result.counted,
      notes: result.notes,
    );
  }
}

class _ClosedShiftCard extends StatelessWidget {
  const _ClosedShiftCard({required this.shift});

  final ShiftSummary shift;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final difference = shift.difference ?? 0;
    final color = difference == 0
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shiftClosedTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Space.sm),
            _MetricRow(label: l10n.shiftExpectedCash, amount: shift.expectedCash),
            _MetricRow(
              label: l10n.shiftCountedCash,
              amount: shift.countedCash ?? 0,
            ),
            Row(
              children: [
                Text(l10n.shiftDifference),
                const Spacer(),
                MoneyText(
                  difference,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
            if (shift.notes != null && shift.notes!.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              Text(shift.notes!),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => exportShiftPdf(context, shift),
                icon: const Icon(Icons.ios_share),
                label: Text(l10n.actionExportPdf),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.shift});

  final ShiftSummary shift;

  @override
  Widget build(BuildContext context) {
    final difference = shift.difference ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: ListTile(
        onTap: shift.isOpen ? null : () => _adjust(context),
        title: Text(Formatters.dateTime(shift.openedAt)),
        subtitle: Text(
          '${context.l10n.shiftSales}: ${Formatters.money(shift.revenue)} · '
          '${context.l10n.shiftDifference}: ${Formatters.money(difference)}',
        ),
        trailing: shift.isOpen
            ? Icon(
                Icons.lock_open,
                color: Theme.of(context).colorScheme.primary,
              )
            : PopupMenuButton<String>(
                tooltip: context.l10n.shiftHistoryFilter,
                onSelected: (action) => action == 'export'
                    ? exportShiftPdf(context, shift)
                    : _adjust(context),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'export',
                    child: Text(context.l10n.actionExportPdf),
                  ),
                  PopupMenuItem(
                    value: 'adjust',
                    child: Text(context.l10n.shiftAdjust),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _adjust(BuildContext context) async {
    final result = await showDialog<_CloseResult>(
      context: context,
      builder: (_) => _AdjustShiftDialog(expected: shift.expectedCash),
    );
    if (result != null && context.mounted) {
      await context.read<ShiftCubit>().adjust(
        shiftId: shift.id,
        countedCash: result.counted,
        reason: result.notes ?? '',
      );
    }
  }
}

class _AdjustShiftDialog extends StatefulWidget {
  const _AdjustShiftDialog({required this.expected});

  /// Cash the shift should hold, to show the difference while counting.
  final int expected;

  @override
  State<_AdjustShiftDialog> createState() => _AdjustShiftDialogState();
}

class _AdjustShiftDialogState extends State<_AdjustShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _counted = TextEditingController();
  final _reason = TextEditingController();

  Future<void> _countWithDenominations() async {
    final total = await showCashCountSheet(context);
    if (total == null || !mounted) {
      return;
    }
    setState(() => _counted.text = Money.input(total));
  }

  @override
  void dispose() {
    _counted.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _CloseResult(
        Money.parse(_counted.text.trim()) ?? 0,
        _reason.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.shiftAdjust),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExpectedRow(expected: widget.expected),
            const SizedBox(height: Space.sm),
            TextFormField(
              controller: _counted,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: moneyInputFormatters(),
              decoration: InputDecoration(
                labelText: l10n.shiftCountedCash,
                suffixIcon: IconButton(
                  tooltip: l10n.cashCountTitle,
                  icon: const Icon(Icons.calculate_outlined),
                  onPressed: _countWithDenominations,
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final amount = Money.parse(value);
                return amount == null || amount < 0
                    ? l10n.invalidAmount
                    : null;
              },
            ),
            _DifferenceRow(counted: _counted.text, expected: widget.expected),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _reason,
              decoration: InputDecoration(labelText: l10n.shiftReason),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.fieldRequired
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}

class _ExpectedRow extends StatelessWidget {
  const _ExpectedRow({required this.expected});

  final int expected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.shiftExpectedCash,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          Formatters.money(expected),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Live difference while the operator types the counted cash.
class _DifferenceRow extends StatelessWidget {
  const _DifferenceRow({required this.counted, required this.expected});

  final String counted;
  final int expected;

  @override
  Widget build(BuildContext context) {
    final value = Money.parse(counted.trim());
    if (value == null) {
      return const SizedBox.shrink();
    }
    final difference = value - expected;
    final status = StatusColors.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.shiftDifference,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Text(
            Formatters.money(difference),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: difference == 0
                  ? status.success
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.amount,
    this.bold = false,
    this.money = true,
  });

  final String label;
  final int amount;
  final bool bold;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          if (money)
            MoneyText(amount, style: style)
          else
            Text('$amount', style: style),
        ],
      ),
    );
  }
}

class _MovementResult {
  const _MovementResult(this.amount, this.reason);

  final int amount;
  final String reason;
}

class _CashMovementDialog extends StatefulWidget {
  const _CashMovementDialog({required this.type});

  final String type;

  @override
  State<_CashMovementDialog> createState() => _CashMovementDialogState();
}

class _CashMovementDialogState extends State<_CashMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _MovementResult(
        Money.parse(_amount.text.trim()) ?? 0,
        _reason.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final withdrawal = widget.type == 'withdrawal';
    return AlertDialog(
      title: Text(withdrawal ? l10n.shiftWithdraw : l10n.shiftDeposit),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: moneyInputFormatters(),
              decoration: InputDecoration(labelText: l10n.fieldAmount),
              validator: (value) {
                final amount = Money.parse(value);
                return amount == null || amount <= 0
                    ? l10n.invalidAmount
                    : null;
              },
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _reason,
              decoration: InputDecoration(labelText: l10n.shiftReason),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.fieldRequired
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.actionConfirm)),
      ],
    );
  }
}

class _CloseResult {
  const _CloseResult(this.counted, this.notes);

  final int counted;
  final String? notes;
}

class _CloseShiftDialog extends StatefulWidget {
  const _CloseShiftDialog({required this.expected});

  /// Cash the shift should hold, to show the difference while counting.
  final int expected;

  @override
  State<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<_CloseShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _counted = TextEditingController();
  final _notes = TextEditingController();

  Future<void> _countWithDenominations() async {
    final total = await showCashCountSheet(context);
    if (total == null || !mounted) {
      return;
    }
    setState(() => _counted.text = '$total');
  }

  @override
  void dispose() {
    _counted.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _CloseResult(
        int.parse(_counted.text.trim()),
        _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.shiftClose),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExpectedRow(expected: widget.expected),
            const SizedBox(height: Space.sm),
            TextFormField(
              controller: _counted,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.shiftCountedCash,
                suffixIcon: IconButton(
                  tooltip: l10n.cashCountTitle,
                  icon: const Icon(Icons.calculate_outlined),
                  onPressed: _countWithDenominations,
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final amount = int.tryParse((value ?? '').trim());
                return amount == null || amount < 0
                    ? l10n.invalidAmount
                    : null;
              },
            ),
            _DifferenceRow(counted: _counted.text, expected: widget.expected),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.shiftNotes),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.actionConfirm)),
      ],
    );
  }
}
