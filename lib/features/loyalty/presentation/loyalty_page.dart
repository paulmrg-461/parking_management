import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/plate_text.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/loyalty_admin_cubit.dart';
import '../domain/entities/loyalty_account.dart';
import '../domain/entities/loyalty_settings.dart';
import 'loyalty_adjust_dialog.dart';
import 'loyalty_report_section.dart';
import 'loyalty_settings_form.dart';

/// Admin screen: program settings, members and the impact report.
class LoyaltyPage extends StatefulWidget {
  const LoyaltyPage({super.key});

  @override
  State<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends State<LoyaltyPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(context.read<LoyaltyAdminCubit>().load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _adjust(
    BuildContext context,
    LoyaltyAccount account,
    LoyaltySettings settings,
  ) async {
    final result = await showLoyaltyAdjustDialog(
      context,
      plate: account.plate,
      progress: account.progress,
      required: settings.visitsRequired,
    );
    if (result == null || !context.mounted) {
      return;
    }
    await context.read<LoyaltyAdminCubit>().adjust(
      plate: account.plate,
      delta: result.delta,
      reason: result.reason,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.loyaltyTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.loyaltyTabProgram),
              Tab(text: l10n.loyaltyTabMembers),
              Tab(text: l10n.loyaltyTabReport),
            ],
          ),
        ),
        body: BlocConsumer<LoyaltyAdminCubit, LoyaltyAdminState>(
          listenWhen: (previous, current) =>
              current is LoyaltyAdminLoaded &&
              previous is LoyaltyAdminLoaded &&
              current.submission != previous.submission,
          listener: (context, state) {
            if (state is! LoyaltyAdminLoaded) {
              return;
            }
            final submission = state.submission;
            if (submission is SubmissionSucceeded) {
              showInfoSnack(context, l10n.loyaltySaved);
            } else if (submission is SubmissionFailed) {
              final failed = submission;
              showErrorSnack(
                context,
                l10n.errorText(failed.message, failed.failure),
              );
            }
          },
          builder: (context, state) => switch (state) {
            LoyaltyAdminInitial() || LoyaltyAdminLoading() =>
              const SkeletonList(),
            LoyaltyAdminFailure(:final message, :final failure) => Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: ErrorState(
                message: l10n.errorText(message, failure),
                onRetry: context.read<LoyaltyAdminCubit>().load,
              ),
            ),
            LoyaltyAdminLoaded(
              :final settings,
              :final accounts,
              :final report,
              :final submission,
            ) =>
              TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(Space.md),
                    children: [
                      LoyaltySettingsForm(
                        settings: settings,
                        busy: submission.isInProgress,
                        onSave: (next) =>
                            context.read<LoyaltyAdminCubit>().save(next),
                      ),
                    ],
                  ),
                  _MembersTab(
                    settings: settings,
                    accounts: accounts,
                    controller: _search,
                    onSearch: (value) =>
                        context.read<LoyaltyAdminCubit>().search(value),
                    onAdjust: (account) =>
                        unawaited(_adjust(context, account, settings)),
                    onEnable: () => context.read<LoyaltyAdminCubit>().save(
                      settings.copyWith(enabled: true),
                    ),
                  ),
                  LoyaltyReportSection(
                    report: report,
                    onRefresh: (start, end) =>
                        context.read<LoyaltyAdminCubit>().loadReport(start, end),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.settings,
    required this.accounts,
    required this.controller,
    required this.onSearch,
    required this.onAdjust,
    required this.onEnable,
  });

  final LoyaltySettings settings;
  final List<LoyaltyAccount> accounts;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final ValueChanged<LoyaltyAccount> onAdjust;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        TextField(
          key: const Key('loyalty_search'),
          controller: controller,
          onChanged: onSearch,
          decoration: InputDecoration(
            labelText: l10n.loyaltySearchPlate,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: Space.md),
        if (accounts.isEmpty)
          EmptyState(
            title: l10n.loyaltyTabMembers,
            message: l10n.loyaltyMembersEmpty,
            icon: Icons.loyalty_outlined,
            action: settings.enabled
                ? null
                : FilledButton.icon(
                    key: const Key('loyalty_enable_cta'),
                    onPressed: onEnable,
                    icon: const Icon(Icons.power_settings_new),
                    label: Text(l10n.loyaltyEnableCta),
                  ),
          )
        else
          for (final account in accounts)
            Card(
              key: Key('loyalty_member_${account.plate}'),
              margin: const EdgeInsets.only(bottom: Space.sm),
              child: ListTile(
                leading: PlateText(account.plate),
                title: Text(
                  l10n.loyaltyVisitOf(
                    account.progress + 1,
                    settings.visitsRequired,
                  ),
                ),
                subtitle: Text('${account.earnedTotal} · ${account.redeemedTotal}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (account.rewardCount > 0)
                      StatusChip(
                        label: '${account.rewardCount}',
                        tone: StatusTone.success,
                        icon: Icons.card_giftcard,
                      ),
                    IconButton(
                      key: Key('loyalty_adjust_${account.plate}'),
                      tooltip: l10n.loyaltyAdjust,
                      onPressed: () => onAdjust(account),
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
