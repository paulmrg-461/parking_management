import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';

import '../application/merchants_cubit.dart';
import '../domain/entities/merchant.dart';
import 'merchant_credentials_dialog.dart';
import 'merchant_form_dialog.dart';
import 'merchant_settlement_section.dart';

/// Admin screen: agreements, the per-vehicle policy and the settlement tab.
class MerchantsPage extends StatefulWidget {
  const MerchantsPage({super.key});

  @override
  State<MerchantsPage> createState() => _MerchantsPageState();
}

class _MerchantsPageState extends State<MerchantsPage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<MerchantsCubit>().load());
  }

  Future<void> _openForm(BuildContext context, {Merchant? merchant}) async {
    final draft = await showMerchantFormDialog(context, merchant: merchant);
    if (draft == null || !context.mounted) {
      return;
    }
    await context.read<MerchantsCubit>().save(draft);
  }

  Future<void> _showCredentialsIfAny(BuildContext context, MerchantsLoaded state) async {
    final credentials = state.justCreated;
    if (credentials == null) {
      return;
    }
    context.read<MerchantsCubit>().dismissCredentials();
    await showMerchantCredentialsDialog(context, credentials);
  }

  Future<void> _confirmDelete(BuildContext context, Merchant merchant) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.merchantDeleteConfirm(merchant.name),
        body: l10n.merchantFormBilling,
        confirmLabel: l10n.actionDelete,
        destructive: true,
      ),
    );
    if (confirmed && context.mounted) {
      await context.read<MerchantsCubit>().delete(merchant.id);
    }
  }

  Future<void> _policy(BuildContext context, int current) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _PolicyDialog(current: current),
    );
    if (value != null && context.mounted) {
      await context.read<MerchantsCubit>().savePolicy(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.merchantsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(l10n.merchantsTitle),
                ),
                ButtonSegment(
                  value: 1,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(l10n.merchantSettlementTitle),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (value) =>
                  setState(() => _tab = value.first),
            ),
          ),
        ),
      ),
      body: _tab == 1
          ? const MerchantSettlementSection()
          : BlocConsumer<MerchantsCubit, MerchantsState>(
              listenWhen: (previous, current) =>
                  current is MerchantsLoaded &&
                  current.justCreated != null,
              listener: (context, state) {
                if (state is MerchantsLoaded) {
                  unawaited(_showCredentialsIfAny(context, state));
                }
              },
              builder: (context, state) => switch (state) {
                MerchantsInitial() || MerchantsLoading() => const SkeletonList(),
                MerchantsFailure(:final failure) => Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: ErrorState(
                    message: l10n.failure(failure),
                    onRetry: context.read<MerchantsCubit>().load,
                  ),
                ),
                MerchantsLoaded(:final merchants, :final maxPerSession) =>
                  _list(context, merchants, maxPerSession),
              },
            ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              key: const Key('merchant_add'),
              onPressed: () => unawaited(_openForm(context)),
              icon: const Icon(Icons.add),
              label: Text(l10n.merchantsAdd),
            )
          : null,
    );
  }

  Widget _list(
    BuildContext context,
    List<Merchant> merchants,
    int maxPerSession,
  ) {
    final l10n = context.l10n;
    if (merchants.isEmpty) {
      return Center(
        child: EmptyState(
          message: l10n.merchantsEmpty,
          icon: Icons.storefront_outlined,
          action: FilledButton.icon(
            onPressed: () => unawaited(_openForm(context)),
            icon: const Icon(Icons.add),
            label: Text(l10n.merchantsAdd),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xxl),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.merchantPolicyTitle),
            subtitle: Text(l10n.merchantPolicyMax),
            trailing: Text('$maxPerSession'),
            onTap: () => unawaited(_policy(context, maxPerSession)),
          ),
        ),
        const SizedBox(height: Space.md),
        for (final merchant in merchants)
          _MerchantCard(
            merchant: merchant,
            onEdit: () => unawaited(_openForm(context, merchant: merchant)),
            onReset: (rotate) => unawaited(
              context.read<MerchantsCubit>().resetCredentials(
                merchant.id,
                rotateToken: rotate,
              ),
            ),
            onDelete: () => unawaited(_confirmDelete(context, merchant)),
          ),
      ],
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({
    required this.merchant,
    required this.onEdit,
    required this.onReset,
    required this.onDelete,
  });

  final Merchant merchant;
  final VoidCallback onEdit;
  final void Function(bool rotate) onReset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final benefit = switch (merchant.kind) {
      MerchantBenefitKind.freeMinutes =>
        l10n.validateBenefitMinutes(merchant.value),
      MerchantBenefitKind.percentage =>
        l10n.validateBenefitPercent(merchant.value),
      MerchantBenefitKind.fixedAmount =>
        l10n.validateBenefitAmount(Money.format(merchant.value)),
    };
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
                  child: Text(merchant.name, style: theme.textTheme.titleMedium),
                ),
                if (!merchant.active)
                  StatusChip(
                    label: l10n.merchantFormActive,
                    tone: StatusTone.neutral,
                  ),
                if (merchant.locked)
                  Padding(
                    padding: const EdgeInsets.only(left: Space.xs),
                    child: StatusChip(
                      label: l10n.merchantLocked,
                      tone: StatusTone.warning,
                      icon: Icons.lock_outline,
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                      case 'pin':
                        onReset(false);
                      case 'rotate':
                        onReset(true);
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(l10n.actionEdit)),
                    PopupMenuItem(value: 'pin', child: Text(l10n.merchantResetPin)),
                    PopupMenuItem(
                      value: 'rotate',
                      child: Text(l10n.merchantRotateToken),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.actionDelete),
                    ),
                  ],
                ),
              ],
            ),
            Text(benefit, style: theme.textTheme.bodyMedium),
            const SizedBox(height: Space.xs),
            Text(
              l10n.merchantUsage(merchant.usedToday, merchant.usedMonth),
              style: theme.textTheme.bodySmall,
            ),
            Text(
              l10n.merchantPending(merchant.pendingNow),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyDialog extends StatefulWidget {
  const _PolicyDialog({required this.current});

  final int current;

  @override
  State<_PolicyDialog> createState() => _PolicyDialogState();
}

class _PolicyDialogState extends State<_PolicyDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.current}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.merchantPolicyTitle),
    content: TextField(
      key: const Key('merchant_policy_value'),
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: context.l10n.merchantPolicyMax),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.actionCancel),
      ),
      FilledButton(
        key: const Key('merchant_policy_save'),
        onPressed: () =>
            Navigator.of(context).pop(int.tryParse(_controller.text)),
        child: Text(context.l10n.actionSave),
      ),
    ],
  );
}
