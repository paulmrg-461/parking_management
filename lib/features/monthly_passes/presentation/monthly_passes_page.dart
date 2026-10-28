import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/network/connectivity_cubit.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/receipt/payment_method.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/search_field.dart';
import '../../../app/di/injection.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../core/widgets/plate_text.dart';
import '../../../core/widgets/status_chip.dart';
import '../../customer_messages/domain/repositories/customer_message_repository.dart';
import '../../settings/application/whatsapp_mode.dart';
import '../../settings/domain/whatsapp_url.dart';
import 'customer_message.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/submission_listener.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../application/monthly_passes_cubit.dart';
import '../domain/commands/create_monthly_pass_command.dart';
import '../domain/commands/update_monthly_pass_command.dart';
import '../domain/entities/monthly_pass.dart';
import '../domain/entities/monthly_pass_payment.dart';
import 'monthly_pass_dialog.dart';

/// Admin-only reference-data CRUD screen for monthly passes. Plates are
/// resolved once in [MonthlyPassesCubit] (vehicleId → plate map).
class MonthlyPassesPage extends StatefulWidget {
  const MonthlyPassesPage({super.key});

  @override
  State<MonthlyPassesPage> createState() => _MonthlyPassesPageState();
}

class _MonthlyPassesPageState extends State<MonthlyPassesPage> {
  String _query = '';
  bool _onlyActive = false;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<MonthlyPassesCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    return ListPageScaffold(
      title: context.l10n.monthlyPassesTitle,
      addTooltip: context.l10n.monthlyPassAddTooltip,
      onAdd: () => _showCreateDialog(context),
      onRefresh: context.read<MonthlyPassesCubit>().load,
      body: SubmissionListener<MonthlyPassesCubit, MonthlyPassesState>(
        submissionOf: _submissionOf,
        onSuccess: (context, _) => _confirmAction(context),
        child: BlocBuilder<MonthlyPassesCubit, MonthlyPassesState>(
          buildWhen: (previous, current) =>
              previous is! MonthlyPassesLoaded ||
              current is! MonthlyPassesLoaded ||
              previous.monthlyPasses != current.monthlyPasses ||
              previous.pendingPayments != current.pendingPayments ||
              previous.plates != current.plates,
          builder: (context, state) => AsyncView<MonthlyPassesLoaded>(
            status: _status(context, state),
            builder: (loaded) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    children: [
                      _Summary(loaded: loaded),
                      const SizedBox(height: Space.md),
                      FilterBar(
                        summary: context.l10n.monthlyPassesCount(
                          [
                            for (final pass in loaded.monthlyPasses)
                              if (_matches(loaded.plateOf(pass)) &&
                                  (!_onlyActive || _isActive(pass)))
                                pass,
                          ].length,
                        ),
                        onClear: _query.trim().isEmpty && !_onlyActive
                            ? null
                            : _clearFilters,
                        clearLabel: context.l10n.actionClearFilters,
                        children: [
                          SizedBox(
                            width: 240,
                            child: SearchField(
                              label: context.l10n.searchPlate,
                              onChanged: (value) =>
                                  setState(() => _query = value),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: Layout.minTouch,
                            ),
                            child: FilterChip(
                              selected: _onlyActive,
                              showCheckmark: false,
                              avatar: const Icon(
                                Icons.verified_outlined,
                                size: 18,
                              ),
                              label: Text(
                                context.l10n.monthlyPassesOnlyActive,
                              ),
                              onSelected: (value) =>
                                  setState(() => _onlyActive = value),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildList(context, loaded)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _matches(String plate) =>
      _query.trim().isEmpty ||
      plate.toLowerCase().contains(_query.trim().toLowerCase());

  bool _isActive(MonthlyPass pass) =>
      pass.active && monthlyPassStatus(pass, DateTime.now()) ==
          MonthlyPassStatus.active;

  void _clearFilters() => setState(() {
    _query = '';
    _onlyActive = false;
  });

  Widget _buildList(BuildContext context, MonthlyPassesLoaded loaded) {
    final l10n = context.l10n;
    final payments = [
      for (final payment in loaded.pendingPayments)
        if (_matches(payment.plate)) payment,
    ];
    final passes = [
      for (final pass in loaded.monthlyPasses)
        if (_matches(loaded.plateOf(pass)) &&
            (!_onlyActive || _isActive(pass)))
          pass,
    ];
    final filtered = _query.trim().isNotEmpty || _onlyActive;
    if (payments.isEmpty && passes.isEmpty) {
      return EmptyState(
        icon: filtered ? Icons.filter_alt_off_outlined : Icons.search_off,
        title: filtered ? l10n.monthlyPassesFilteredEmpty : null,
        message: filtered && _query.trim().isNotEmpty
            ? l10n.monthlyPassesNoMatch(_query.trim())
            : l10n.monthlyPassesFilteredEmpty,
        action: filtered
            ? FilledButton.tonalIcon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(l10n.actionClearFilters),
              )
            : null,
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl * 2),
      children: [
        if (payments.isNotEmpty) ...[
          SectionHeader(
            icon: Icons.payments_outlined,
            title: l10n.monthlyPassPendingTitle,
            padding: const EdgeInsets.fromLTRB(
              Space.md,
              Space.sm,
              Space.md,
              Space.sm,
            ),
            action: Text(
              '${payments.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          for (final payment in payments) _PendingPaymentTile(payment: payment),
          const Divider(),
        ],
        if (passes.isNotEmpty) ...[
          SectionHeader(
            icon: Icons.card_membership,
            title: l10n.monthlyPassesList,
            padding: const EdgeInsets.fromLTRB(
              Space.md,
              Space.sm,
              Space.md,
              Space.sm,
            ),
          ),
          for (final pass in passes)
            _MonthlyPassTile(
              monthlyPass: pass,
              plate: loaded.plateOf(pass),
              phone: loaded.phoneOf(pass),
            ),
        ],
      ],
    );
  }

  AsyncStatus<MonthlyPassesLoaded> _status(
    BuildContext context,
    MonthlyPassesState state,
  ) => switch (state) {
    MonthlyPassesInitial() || MonthlyPassesLoading() => const AsyncLoading(),
    MonthlyPassesFailure(:final message, :final failure) => AsyncFailed(
      context.l10n.errorText(message, failure),
      context.read<MonthlyPassesCubit>().load,
    ),
    MonthlyPassesLoaded(:final monthlyPasses) when monthlyPasses.isEmpty =>
      AsyncEmpty(
        context.l10n.monthlyPassesEmptyHint,
        title: context.l10n.monthlyPassesEmpty,
        icon: Icons.card_membership_outlined,
        action: FilledButton.icon(
          onPressed: () => _showCreateDialog(context),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.monthlyPassAddTooltip),
        ),
      ),
    final MonthlyPassesLoaded loaded => AsyncReady(loaded),
  };

  static Submission? _submissionOf(MonthlyPassesState state) =>
      state is MonthlyPassesLoaded ? state.submission : null;

  /// Confirms creates, edits, deletes and payment collections in text and to
  /// screen readers.
  void _confirmAction(BuildContext context) {
    final state = context.read<MonthlyPassesCubit>().state;
    final action = state is MonthlyPassesLoaded ? state.lastAction : null;
    final l10n = context.l10n;
    final message = switch (action) {
      MonthlyPassAction.created => l10n.monthlyPassCreated,
      MonthlyPassAction.deleted => l10n.monthlyPassDeleted,
      MonthlyPassAction.payment => l10n.monthlyPassPaymentDone,
      MonthlyPassAction.renewed => l10n.monthlyPassRenewed,
      null => null,
    };
    if (message == null) {
      return;
    }
    SemanticsService.announce(message, Directionality.of(context));
    showInfoSnack(context, message);
  }

  void _showCreateDialog(BuildContext context) {
    final cubit = context.read<MonthlyPassesCubit>();
    final state = cubit.state;
    final vehicles = state is MonthlyPassesLoaded
        ? state.vehicles
        : const <Vehicle>[];
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => MonthlyPassDialog(
          vehicles: vehicles,
          onSave: (draft) => cubit.create(
            CreateMonthlyPassCommand(
              vehicleId: draft.vehicleId!,
              startDate: draft.startDate,
              endDate: draft.endDate,
              amount: draft.amount,
              autoRenew: draft.autoRenew,
              autoRenewPaymentMethod: draft.autoRenewPaymentMethod,
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.loaded});

  final MonthlyPassesLoaded loaded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final active = loaded.monthlyPasses
        .where(
          (pass) =>
              pass.active &&
              monthlyPassStatus(pass, now) == MonthlyPassStatus.active,
        )
        .length;
    final pending = loaded.pendingPayments.length;
    final due = loaded.pendingPayments.fold<int>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MetricCard(
              icon: Icons.verified_outlined,
              label: l10n.monthlyPassesActive,
              value: '$active',
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: MetricCard(
              icon: Icons.payments_outlined,
              label: l10n.monthlyPassPendingTitle,
              value: '$pending',
              caption: pending == 0 ? null : Formatters.money(due),
              tone: pending == 0 ? MetricTone.neutral : MetricTone.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyPassTile extends StatelessWidget {
  const _MonthlyPassTile({
    required this.monthlyPass,
    required this.plate,
    this.phone,
  });

  final MonthlyPass monthlyPass;
  final String plate;
  final String? phone;

  Future<void> _notify(BuildContext context) async {
    if (whatsappAutoEnabled(context)) {
      await _queueReminder(context);
      return;
    }
    final url = whatsappUrl(
      phone!,
      text: monthlyPassWhatsappMessage(
        l10n: context.l10n,
        plate: plate,
        monthlyPass: monthlyPass,
      ),
    );
    await openWhatsapp(context, url);
  }

  Future<void> _queueReminder(BuildContext context) async {
    final l10n = context.l10n;
    if (!serviceLocator.isRegistered<CustomerMessageRepository>()) {
      return;
    }
    try {
      await serviceLocator<CustomerMessageRepository>().enqueueWhatsapp(
        phone: phone!,
        template: 'pass_expiry',
        params: [plate, Formatters.date(monthlyPass.endDate)],
      );
      if (context.mounted) {
        showInfoSnack(context, l10n.whatsappQueued);
      }
    } on Failure catch (failure) {
      if (context.mounted) {
        showErrorSnack(context, l10n.failure(failure));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = l10n.monthlyPassPeriod(
      Formatters.date(monthlyPass.startDate),
      Formatters.date(monthlyPass.endDate),
    );
    final status = monthlyPassStatus(monthlyPass, DateTime.now());
    final (statusLabel, statusTone) = switch (status) {
      MonthlyPassStatus.active => (l10n.monthlyPassStatusActive, StatusTone.success),
      MonthlyPassStatus.upcoming => (
        l10n.monthlyPassStatusUpcoming,
        StatusTone.warning,
      ),
      MonthlyPassStatus.expired => (
        l10n.monthlyPassStatusExpired,
        StatusTone.neutral,
      ),
    };
    return ListTile(
      title: Row(
        children: [
          PlateText(plate),
          const SizedBox(width: Space.sm),
          AnimatedSwitcher(
            duration: Motion.short,
            child: StatusChip(
              key: ValueKey(statusLabel),
              label: statusLabel,
              tone: statusTone,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$period · ${Formatters.money(monthlyPass.amount)}'
            '${monthlyPass.autoRenew ? ' · ${l10n.monthlyPassAutoRenew}' : ''}',
          ),
          if (monthlyPass.active && monthlyPass.needsRenewal())
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _renew(context),
                icon: const Icon(Icons.event_repeat, size: 18),
                label: Text(l10n.monthlyPassRenew),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l10n.monthlyPassActiveLabel(plate),
            child: Switch(
              value: monthlyPass.active,
              onChanged: (_) => _toggle(context),
            ),
          ),
          if (monthlyPass.autoRenew)
            Icon(
              Icons.autorenew,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: l10n.monthlyPassAutoRenew,
            ),
          if (phone != null && monthlyPass.active)
            AppIconButton(
              icon: Icons.chat_outlined,
              tooltip: l10n.monthlyPassWhatsapp,
              onPressed: () => _notify(context),
            ),
          AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: l10n.monthlyPassEditTooltip(plate),
            onPressed: () => _edit(context),
          ),
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: l10n.monthlyPassDeleteTooltip(plate),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _toggle(BuildContext context) {
    final cubit = context.read<MonthlyPassesCubit>();
    final id = monthlyPass.id!;
    final next = !monthlyPass.active;
    unawaited(cubit.update(UpdateMonthlyPassCommand(id: id, active: next)));
    if (!next) {
      showUndoSnack(
        context,
        message: context.l10n.monthlyPassDeactivated(plate),
        onUndo: () =>
            cubit.update(UpdateMonthlyPassCommand(id: id, active: true)),
      );
    }
  }

  Future<void> _renew(BuildContext context) async {
    final l10n = context.l10n;
    final period = monthlyPass.renewedPeriod();
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.monthlyPassRenewTitle,
        body: l10n.monthlyPassRenewBody(Formatters.date(period.end)),
        confirmLabel: l10n.monthlyPassRenew,
      ),
    );
    if (confirmed && context.mounted) {
      await context.read<MonthlyPassesCubit>().renew(monthlyPass);
    }
  }

  void _edit(BuildContext context) {
    final cubit = context.read<MonthlyPassesCubit>();
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => MonthlyPassDialog(
          existing: monthlyPass,
          onSave: (draft) => cubit.update(
            UpdateMonthlyPassCommand(
              id: monthlyPass.id!,
              startDate: draft.startDate,
              endDate: draft.endDate,
              amount: draft.amount,
              autoRenew: draft.autoRenew,
              autoRenewPaymentMethod: draft.autoRenewPaymentMethod,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<MonthlyPassesCubit>();
    final l10n = context.l10n;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.monthlyPassDeleteTitle,
        body: l10n.monthlyPassDeleteBody(plate),
        confirmLabel: l10n.actionDelete,
        destructive: true,
      ),
    );
    if (confirmed) {
      await cubit.delete(monthlyPass.id!);
    }
  }
}


class _PendingPaymentTile extends StatelessWidget {
  const _PendingPaymentTile({required this.payment});

  final MonthlyPassPayment payment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: Text(
        '${payment.plate} · ${Formatters.money(payment.amount)}',
      ),
      subtitle: Text(
        '${l10n.monthlyPassDue(Formatters.date(payment.dueDate))} · '
        '${paymentMethodLabel(l10n, payment.paymentMethod)}',
      ),
      trailing: FilledButton(
        onPressed: _online(context) ? () => _pay(context) : null,
        child: Text(l10n.monthlyPassCharge),
      ),
    );
  }

  bool _online(BuildContext context) {
    try {
      return context.watch<ConnectivityCubit>().state;
    } on ProviderNotFoundException {
      return true;
    }
  }

  Future<void> _pay(BuildContext context) async {
    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (_) => const _PaymentMethodDialog(),
    );
    if (method != null && context.mounted) {
      await context.read<MonthlyPassesCubit>().registerPayment(
        payment.id,
        method.wire,
      );
    }
  }
}

class _PaymentMethodDialog extends StatefulWidget {
  const _PaymentMethodDialog();

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  PaymentMethod _method = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.paymentMethodTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final method in const [
            PaymentMethod.cash,
            PaymentMethod.card,
            PaymentMethod.transfer,
          ])
            RadioListTile<PaymentMethod>(
              value: method,
              groupValue: _method,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _method = value);
                }
              },
              title: Text(method.label(context.l10n)),
              secondary: Icon(method.icon),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_method),
          child: Text(context.l10n.actionConfirm),
        ),
      ],
    );
  }
}
