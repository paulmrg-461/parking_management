import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/shift_cubit.dart';
import '../domain/entities/shift_summary.dart';

class ShiftPage extends StatefulWidget {
  const ShiftPage({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<ShiftPage> createState() => _ShiftPageState();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<ShiftCubit, ShiftState>(
      listenWhen: (previous, current) =>
          submissionJustFailed(previous.submission, current.submission),
      listener: (context, state) {
        if (state.submission case SubmissionFailed(:final message, :final failure)) {
          showErrorSnack(context, l10n.errorText(message, failure));
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
            ShiftStatus.loaded => _Content(state: state, isAdmin: widget.isAdmin),
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.isAdmin});

  final ShiftState state;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = state.current;
    return RefreshIndicator(
      onRefresh: () => context.read<ShiftCubit>().load(admin: isAdmin),
      child: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
        if (current != null)
          _OpenShiftCard(shift: current)
        else ...[
          const _OpenShiftForm(),
          if (state.lastClosed != null) ...[
            const SizedBox(height: Space.lg),
            _ClosedShiftCard(shift: state.lastClosed!),
          ],
        ],
        if (isAdmin && state.history.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          Text(l10n.shiftHistory, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          for (final shift in state.history) _HistoryTile(shift: shift),
        ],
        ],
      ),
    );
  }
}

class _OpenShiftForm extends StatefulWidget {
  const _OpenShiftForm();

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
    context.read<ShiftCubit>().open(int.parse(_controller.text.trim()));
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.shiftOpeningFloat,
                ),
                validator: (value) {
                  final amount = int.tryParse((value ?? '').trim());
                  return amount == null || amount < 0
                      ? l10n.invalidAmount
                      : null;
                },
              ),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                onPressed: _open,
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
  const _OpenShiftCard({required this.shift});

  final ShiftSummary shift;

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
                  onPressed: () => _movement(context, 'withdrawal'),
                  icon: const Icon(Icons.remove),
                  label: Text(l10n.shiftWithdraw),
                ),
                OutlinedButton.icon(
                  onPressed: () => _movement(context, 'deposit'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.shiftDeposit),
                ),
                FilledButton.icon(
                  onPressed: () => _close(context),
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
    final result = await showDialog<_CloseResult>(
      context: context,
      builder: (_) => const _CloseShiftDialog(),
    );
    if (result != null && context.mounted) {
      await context.read<ShiftCubit>().closeShift(
        countedCash: result.counted,
        notes: result.notes,
      );
    }
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
            : const Icon(Icons.lock),
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
      _MovementResult(int.parse(_amount.text.trim()), _reason.text.trim()),
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
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.fieldAmount),
              validator: (value) {
                final amount = int.tryParse((value ?? '').trim());
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
  const _CloseShiftDialog();

  @override
  State<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<_CloseShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _counted = TextEditingController();
  final _notes = TextEditingController();

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
            TextFormField(
              controller: _counted,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.shiftCountedCash),
              validator: (value) {
                final amount = int.tryParse((value ?? '').trim());
                return amount == null || amount < 0
                    ? l10n.invalidAmount
                    : null;
              },
            ),
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
