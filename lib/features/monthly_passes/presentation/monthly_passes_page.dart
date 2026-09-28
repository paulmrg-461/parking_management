import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/plate_text.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/submission_listener.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../application/monthly_passes_cubit.dart';
import '../domain/commands/create_monthly_pass_command.dart';
import '../domain/commands/update_monthly_pass_command.dart';
import '../domain/entities/monthly_pass.dart';
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
              previous.plates != current.plates,
          builder: (context, state) => AsyncView<MonthlyPassesLoaded>(
            status: _status(context, state),
            builder: (loaded) => ListView.builder(
              padding: const EdgeInsets.only(bottom: Space.xxl * 2),
              itemCount: loaded.monthlyPasses.length,
              itemBuilder: (context, index) {
                final pass = loaded.monthlyPasses[index];
                return _MonthlyPassTile(
                  monthlyPass: pass,
                  plate:
                      loaded.plates[pass.vehicleId] ??
                      context.l10n.unknownVehicle(pass.vehicleId),
                );
              },
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
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlyPassTile extends StatelessWidget {
  const _MonthlyPassTile({required this.monthlyPass, required this.plate});

  final MonthlyPass monthlyPass;
  final String plate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = l10n.monthlyPassPeriod(
      Formatters.date(monthlyPass.startDate),
      Formatters.date(monthlyPass.endDate),
    );
    return ListTile(
      title: PlateText(plate),
      subtitle: Text('$period · ${Formatters.money(monthlyPass.amount)}'),
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
