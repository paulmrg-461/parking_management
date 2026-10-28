import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/plate_text.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/records_cubit.dart';
import '../domain/entities/session_record.dart';

/// Site activity log: every session (entry + exit) with a plate filter. Tapping
/// a row opens that vehicle's full history (visits, spend, notes).
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, this.onOpenHistory});

  /// Test seam: opens the vehicle history without a router.
  final void Function(BuildContext context, String plate)? onOpenHistory;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<RecordsCubit>().load());
  }

  void _openHistory(BuildContext context, String plate) {
    final open = widget.onOpenHistory;
    if (open != null) {
      open(context, plate);
      return;
    }
    context.push('/history?plate=${Uri.encodeQueryComponent(plate)}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recordsTitle),
        actions: [
          IconButton(
            tooltip: l10n.homeRefreshTooltip,
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<RecordsCubit>().load(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: SearchField(
              label: l10n.plateLabel,
              hint: l10n.plateHint,
              onChanged: context.read<RecordsCubit>().search,
              onSubmitted: (value) =>
                  unawaited(context.read<RecordsCubit>().load(query: value)),
            ),
          ),
          Expanded(
            child: BlocConsumer<RecordsCubit, RecordsState>(
              listenWhen: (previous, current) =>
                  previous.failure != current.failure &&
                  current.failure != null &&
                  current.status == RecordsStatus.loaded,
              listener: (context, state) {
                showErrorSnack(context, context.l10n.failure(state.failure!));
              },
              builder: (context, state) => switch (state.status) {
                RecordsStatus.initial || RecordsStatus.loading =>
                  const _RecordsSkeleton(),
                RecordsStatus.failure => ErrorState(
                  message: context.l10n.failure(state.failure!),
                  onRetry: () => context.read<RecordsCubit>().load(),
                ),
                RecordsStatus.loaded => _RecordsList(
                  state: state,
                  onOpen: (plate) => _openHistory(context, plate),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({required this.state, required this.onOpen});

  final RecordsState state;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.records.isEmpty) {
      return EmptyState(
        message: state.query.trim().isEmpty
            ? l10n.recordsEmptyAll
            : l10n.recordsEmpty(state.query),
        icon: Icons.receipt_long_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.lg),
      itemCount: state.records.length + (state.hasMore ? 2 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.recordsCount(state.total),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (state.query.trim().isNotEmpty)
                  TextButton(
                    onPressed: () => context.read<RecordsCubit>().load(
                      query: '',
                    ),
                    child: Text(l10n.recordsClearFilter),
                  ),
              ],
            ),
          );
        }
        if (index > state.records.length) {
          return Center(
            child: TextButton(
              onPressed: () => context.read<RecordsCubit>().loadMore(),
              child: Text(l10n.recordsLoadMore),
            ),
          );
        }
        final record = state.records[index - 1];
        return _RecordTile(record: record, onTap: () => onOpen(record.plate));
      },
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final SessionRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final open = record.isOpen;
    final subtitle = open
        ? l10n.recordsOpenSince(
            Formatters.dateTime(record.entryTime),
            Formatters.duration(l10n, record.duration),
          )
        : l10n.recordsWindow(
            Formatters.duration(l10n, record.duration),
            Formatters.dateTime(record.entryTime),
            Formatters.dateTime(record.exitTime!),
          );
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: open
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  open ? Icons.login : Icons.logout,
                  size: 18,
                  color: open
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PlateText(record.plate),
                        const SizedBox(width: Space.sm),
                        Text(
                          record.category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              if (open)
                StatusChip(label: l10n.statusOpen, tone: StatusTone.warning)
              else
                MoneyText(
                  record.amountCharged,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsSkeleton extends StatelessWidget {
  const _RecordsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Space.md),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (_, _) => const SkeletonBox(height: 72),
    );
  }
}
