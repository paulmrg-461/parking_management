import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../app/di/injection.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../core/widgets/plate_text.dart';
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
        child: BlocBuilder<MonthlyPassesCubit, MonthlyPassesState>(
          buildWhen: (previous, current) =>
              previous is! MonthlyPassesLoaded ||
              current is! MonthlyPassesLoaded ||
              previous.monthlyPasses != current.monthlyPasses ||
              previous.pendingPayments != current.pendingPayments ||
              previous.plates != current.plates,
          builder: (context, state) => AsyncView<MonthlyPassesLoaded>(
            status: _status(context, state),
            builder: (loaded) => ListView(
              padding: const EdgeInsets.only(bottom: Space.xxl * 2),
              children: [
                if (loaded.pendingPayments.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.md,
                      Space.md,
                      Space.md,
                      Space.sm,
                    ),
                    child: Text(
                      context.l10n.monthlyPassPendingTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final payment in loaded.pendingPayments)
                    _PendingPaymentTile(payment: payment),
                  const Divider(),
                ],
                for (final pass in loaded.monthlyPasses)
                  _MonthlyPassTile(
                    monthlyPass: pass,
                    plate:
                        loaded.plates[pass.vehicleId] ??
                        context.l10n.unknownVehicle(pass.vehicleId),
                    phone: loaded.phoneOf(pass),
                  ),
              ],
            ),
          ),
        ),
      ),
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
        context.l10n.monthlyPassesEmpty,
        icon: Icons.card_membership_outlined,
      ),
    final MonthlyPassesLoaded loaded => AsyncReady(loaded),
  };

  static Submission? _submissionOf(MonthlyPassesState state) =>
      state is MonthlyPassesLoaded ? state.submission : null;

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
    return ListTile(
      title: PlateText(plate),
      subtitle: Text(
        '$period · ${Formatters.money(monthlyPass.amount)}'
        '${monthlyPass.autoRenew ? ' · ${l10n.monthlyPassAutoRenew}' : ''}',
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
