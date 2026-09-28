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
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/submission_listener.dart';
import '../../categories/domain/entities/category.dart';
import '../application/tariffs_cubit.dart';
import '../domain/commands/update_tariff_command.dart';
import '../domain/entities/tariff.dart';
import 'create_tariff_dialog.dart';
import 'tariff_labels.dart';

class TariffsPage extends StatefulWidget {
  const TariffsPage({super.key});

  @override
  State<TariffsPage> createState() => _TariffsPageState();
}

class _TariffsPageState extends State<TariffsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<TariffsCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    return ListPageScaffold(
      title: context.l10n.tariffsTitle,
      addTooltip: context.l10n.tariffAddTooltip,
      onAdd: () => _showCreateDialog(context),
      onRefresh: context.read<TariffsCubit>().load,
      body: SubmissionListener<TariffsCubit, TariffsState>(
        submissionOf: _submissionOf,
        child: BlocBuilder<TariffsCubit, TariffsState>(
          buildWhen: (previous, current) =>
              previous is! TariffsLoaded ||
              current is! TariffsLoaded ||
              previous.tariffs != current.tariffs ||
              previous.categoryNames != current.categoryNames,
          builder: (context, state) => AsyncView<TariffsLoaded>(
            status: _status(context, state),
            builder: (loaded) => ListView.builder(
              padding: const EdgeInsets.only(bottom: Space.xxl * 2),
              itemCount: loaded.tariffs.length,
              itemBuilder: (context, index) => _TariffTile(
                tariff: loaded.tariffs[index],
                categoryName: _categoryName(context, loaded, index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _categoryName(BuildContext context, TariffsLoaded loaded, int i) {
    final categoryId = loaded.tariffs[i].categoryId;
    return loaded.categoryNames[categoryId] ??
        context.l10n.categoryFallback(categoryId);
  }

  AsyncStatus<TariffsLoaded> _status(
    BuildContext context,
    TariffsState state,
  ) => switch (state) {
    TariffsInitial() || TariffsLoading() => const AsyncLoading(),
    TariffsFailure(:final message, :final failure) => AsyncFailed(
      context.l10n.errorText(message, failure),
      context.read<TariffsCubit>().load,
    ),
    TariffsLoaded(:final tariffs) when tariffs.isEmpty => AsyncEmpty(
      context.l10n.tariffsEmpty,
      icon: Icons.payments_outlined,
    ),
    final TariffsLoaded loaded => AsyncReady(loaded),
  };

  static Submission? _submissionOf(TariffsState state) =>
      state is TariffsLoaded ? state.submission : null;

  void _showCreateDialog(BuildContext context) {
    final cubit = context.read<TariffsCubit>();
    final state = cubit.state;
    final options = state is TariffsLoaded
        ? state.categories
        : const <Category>[];
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) =>
            CreateTariffDialog(categories: options, onCreate: cubit.create),
      ),
    );
  }
}

class _TariffTile extends StatelessWidget {
  const _TariffTile({required this.tariff, required this.categoryName});

  final Tariff tariff;
  final String categoryName;

  String get _window => tariff.type == TariffType.nightly
      ? ' · ${tariff.startTime}–${tariff.endTime}'
      : '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      title: Text('$categoryName · ${tariff.type.label(l10n)}'),
      subtitle: Text('${Formatters.money(tariff.amount)}$_window'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l10n.tariffActiveLabel,
            child: Switch(
              value: tariff.active,
              onChanged: tariff.id == null ? null : (_) => _toggle(context),
            ),
          ),
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: l10n.tariffDeleteTooltip,
            onPressed: tariff.id == null ? null : () => _delete(context),
          ),
        ],
      ),
    );
  }

  void _toggle(BuildContext context) {
    final cubit = context.read<TariffsCubit>();
    final id = tariff.id!;
    unawaited(cubit.update(UpdateTariffCommand(id: id, active: !tariff.active)));
    if (tariff.active) {
      showUndoSnack(
        context,
        message: context.l10n.tariffDeactivated,
        onUndo: () => cubit.update(UpdateTariffCommand(id: id, active: true)),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<TariffsCubit>();
    final l10n = context.l10n;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.tariffDeleteTitle,
        body: l10n.tariffDeleteBody(
          '$categoryName · ${tariff.type.label(l10n)}',
        ),
        confirmLabel: l10n.actionDelete,
        destructive: true,
      ),
    );
    if (confirmed) {
      await cubit.delete(tariff.id!);
    }
  }
}
