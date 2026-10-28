import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/receipt/pdf_share.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/plate_text.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/sync_badge.dart';
import '../application/records_cubit.dart';
import '../domain/entities/session_record.dart';
import 'records_csv.dart';
import 'records_pdf.dart';

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
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<RecordsCubit>().load());
  }

  Future<void> _copyCsv(BuildContext context) async {
    final rows = await context.read<RecordsCubit>().exportAll();
    if (!context.mounted || rows == null) {
      return;
    }
    if (rows.isEmpty) {
      showInfoSnack(context, context.l10n.recordsExportEmpty);
      return;
    }
    await Clipboard.setData(ClipboardData(text: recordsCsv(rows)));
    if (context.mounted) {
      showInfoSnack(context, context.l10n.recordsCsvCopied);
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    final cubit = context.read<RecordsCubit>();
    setState(() => _exporting = true);
    try {
      final rows = await cubit.exportAll();
      if (!context.mounted || rows == null) {
        return;
      }
      if (rows.isEmpty) {
        showInfoSnack(context, context.l10n.recordsExportEmpty);
        return;
      }
      final state = cubit.state;
      final bytes = await buildRecordsPdf(
        l10n: context.l10n,
        records: rows,
        plate: state.query,
        from: state.from,
        to: state.to,
      );
      if (!context.mounted) {
        return;
      }
      final today = DateTime.now();
      await sharePdfBytes(
        context,
        bytes: bytes,
        filename: pdfFileName(
          'registros',
          state.from ?? today,
          state.to ?? today,
        ),
      );
    } finally {
      if (context.mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _pickRange(BuildContext context) async {
    final state = context.read<RecordsCubit>().state;
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: state.from != null && state.to != null
          ? DateTimeRange(start: state.from!, end: state.to!)
          : null,
      helpText: context.l10n.recordsRangeTooltip,
    );
    if (picked == null || !context.mounted) {
      return;
    }
    await context.read<RecordsCubit>().setRange(picked.start, picked.end);
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
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: l10n.recordsExportCsv,
              icon: const Icon(Icons.ios_share),
              onSelected: (value) => value == 'pdf'
                  ? _exportPdf(context)
                  : _copyCsv(context),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pdf',
                  child: Text(l10n.recordsExportPdf),
                ),
                PopupMenuItem(
                  value: 'csv',
                  child: Text(l10n.recordsExportCsv),
                ),
              ],
            ),
          IconButton(
            tooltip: l10n.homeRefreshTooltip,
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<RecordsCubit>().load(),
          ),
          const SyncBadge(),
        ],
      ),
      body: BlocConsumer<RecordsCubit, RecordsState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure &&
            current.failure != null &&
            current.status == RecordsStatus.loaded,
        listener: (context, state) {
          showErrorSnack(context, context.l10n.failure(state.failure!));
        },
        builder: (context, state) {
          final cubit = context.read<RecordsCubit>();
          final filtered =
              state.query.trim().isNotEmpty ||
              state.from != null ||
              state.to != null;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Space.md),
                child: FilterBar(
                  summary: state.status == RecordsStatus.loaded
                      ? l10n.recordsCount(state.total)
                      : null,
                  onClear: filtered
                      ? () {
                          cubit.setRange(null, null);
                          unawaited(cubit.load(query: ''));
                        }
                      : null,
                  clearLabel: l10n.actionClearFilters,
                  children: [
                    SizedBox(
                      width: 260,
                      child: SearchField(
                        label: l10n.plateLabel,
                        hint: l10n.plateHint,
                        onChanged: cubit.search,
                        onSubmitted: (value) =>
                            unawaited(cubit.load(query: value)),
                      ),
                    ),
                    _RangeFilter(onPick: () => _pickRange(context)),
                  ],
                ),
              ),
              Expanded(
                child: switch (state.status) {
                  RecordsStatus.initial || RecordsStatus.loading =>
                    const _RecordsSkeleton(),
                  RecordsStatus.failure => ErrorState(
                    message: context.l10n.failure(state.failure!),
                    onRetry: () => cubit.load(),
                  ),
                  RecordsStatus.loaded => _RecordsList(
                    state: state,
                    onOpen: (plate) => _openHistory(context, plate),
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RangeFilter extends StatelessWidget {
  const _RangeFilter({required this.onPick});

  final VoidCallback onPick;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTimeRange? _preset(RecordsState state, int days) {
    if (state.from == null || state.to == null) {
      return null;
    }
    final start = _today.subtract(Duration(days: days - 1));
    final same = state.from!.year == start.year &&
        state.from!.month == start.month &&
        state.from!.day == start.day &&
        state.to!.year == _today.year &&
        state.to!.month == _today.month &&
        state.to!.day == _today.day;
    return same ? DateTimeRange(start: start, end: _today) : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<RecordsCubit>().state;
    final cubit = context.read<RecordsCubit>();
    final today = _preset(state, 1) != null;
    final week = _preset(state, 7) != null;
    final month = _preset(state, 30) != null;
    final all = state.from == null && state.to == null;
    final custom = !today && !week && !month && !all;
    Widget chip(String label, bool selected, VoidCallback onTap) =>
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => onTap(),
          ),
        );
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip(l10n.recordsRangeAll, all, () => cubit.setRange(null, null)),
        chip(
          l10n.recordsRangeToday,
          today,
          () => cubit.setRange(_today, _today),
        ),
        chip(
          l10n.recordsRangeWeek,
          week,
          () => cubit.setRange(
            _today.subtract(const Duration(days: 6)),
            _today,
          ),
        ),
        chip(
          l10n.recordsRangeMonth,
          month,
          () => cubit.setRange(
            _today.subtract(const Duration(days: 29)),
            _today,
          ),
        ),
        IconButton.filledTonal(
          tooltip: l10n.recordsRangeTooltip,
          icon: const Icon(Icons.date_range),
          onPressed: onPick,
        ),
        if (custom && state.from != null && state.to != null)
          Text(
            '${Formatters.date(state.from!)} — ${Formatters.date(state.to!)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
      ],
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
        title: l10n.recordsEmptyTitle,
        message: state.query.trim().isEmpty
            ? l10n.recordsEmptyAll
            : l10n.recordsEmpty(state.query),
        icon: Icons.receipt_long_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.lg),
      itemCount: state.records.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (context, index) {
        if (index == state.records.length) {
          return Center(
            child: TextButton(
              onPressed: () => context.read<RecordsCubit>().loadMore(),
              child: Text(l10n.recordsLoadMore),
            ),
          );
        }
        final record = state.records[index];
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
