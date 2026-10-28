import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/receipt/pdf_share.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/audit_cubit.dart';
import '../domain/entities/audit_entry.dart';
import 'audit_export.dart';

/// Admin audit trail: who changed which reference data, when and where.
class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  static const _tables = [
    'users',
    'categories',
    'tariffs',
    'vehicles',
    'monthly_passes',
    'parking_settings',
    'parking_lots',
    'lot_members',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(context.read<AuditCubit>().load());
  }

  Future<void> _pickRange(BuildContext context, AuditState state) async {
    final now = DateTime.now();
    final loaded = state is AuditLoaded ? state : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: loaded?.from == null || loaded?.to == null
          ? null
          : DateTimeRange(start: loaded!.from!, end: loaded.to!),
    );
    if (picked != null && context.mounted) {
      await context.read<AuditCubit>().load(
        from: picked.start,
        to: picked.end,
      );
    }
  }

  Future<void> _exportPdf(BuildContext context, AuditState state) async {
    if (state is! AuditLoaded || state.entries.isEmpty) {
      return;
    }
    final bytes = await buildAuditPdf(
      l10n: context.l10n,
      entries: state.entries,
      subtitle: [
        if (state.table != null) state.table!,
        if (state.actor != null) state.actor!,
      ].join(' · '),
    );
    if (!context.mounted) {
      return;
    }
    await sharePdfBytes(
      context,
      bytes: bytes,
      filename: auditPdfFileName(DateTime.now()),
    );
  }

  Future<void> _copyCsv(BuildContext context, AuditState state) async {
    if (state is! AuditLoaded || state.entries.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: auditCsv(state.entries)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.auditCopied)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.auditTitle),
        actions: [
          BlocBuilder<AuditCubit, AuditState>(
            builder: (context, state) => PopupMenuButton<String>(
              tooltip: l10n.auditExport,
              icon: const Icon(Icons.ios_share),
              onSelected: (value) => value == 'pdf'
                  ? _exportPdf(context, state)
                  : _copyCsv(context, state),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pdf',
                  child: Text(l10n.auditExportPdf),
                ),
                PopupMenuItem(
                  value: 'csv',
                  child: Text(l10n.auditExportCsv),
                ),
              ],
            ),
          ),
          BlocBuilder<AuditCubit, AuditState>(
            builder: (context, state) => IconButton(
              tooltip: l10n.auditFilterDates,
              onPressed: () => _pickRange(context, state),
              icon: const Icon(Icons.date_range),
            ),
          ),
        ],
      ),
      body: BlocBuilder<AuditCubit, AuditState>(
        builder: (context, state) {
          final loaded = state is AuditLoaded ? state : null;
          final filtered =
              loaded != null &&
              (loaded.from != null ||
                  loaded.table != null ||
                  loaded.actor != null);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Space.md),
                child: FilterBar(
                  summary: loaded == null
                      ? null
                      : l10n.auditCount(loaded.entries.length),
                  onClear: filtered
                      ? () => context
                            .read<AuditCubit>()
                            .load(clearFilters: true)
                      : null,
                  clearLabel: l10n.actionClearFilters,
                  children: [
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String?>(
                        initialValue: loaded?.table,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.auditTable,
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l10n.auditAllTables),
                          ),
                          for (final name in _tables)
                            DropdownMenuItem(value: name, child: Text(name)),
                        ],
                        onChanged: (value) =>
                            context.read<AuditCubit>().load(table: value),
                      ),
                    ),
                    if (loaded != null && loaded.actors.isNotEmpty)
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String?>(
                          initialValue: loaded.actor,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.auditActor,
                            isDense: true,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l10n.auditAllActors),
                            ),
                            for (final actor in loaded.actors)
                              DropdownMenuItem(
                                value: actor,
                                child: Text(actor),
                              ),
                          ],
                          onChanged: (value) => context
                              .read<AuditCubit>()
                              .load(actor: value),
                        ),
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: Layout.minTouch,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: () => _pickRange(context, state),
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          loaded?.from == null || loaded?.to == null
                              ? l10n.auditFilterDates
                              : '${Formatters.date(loaded!.from!)} — '
                                    '${Formatters.date(loaded.to!)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (state) {
                  AuditInitial() || AuditLoading() => const SkeletonTable(),
                  AuditFailure(:final message, :final failure) => ErrorState(
                    message: context.l10n.errorText(message, failure),
                    onRetry: () => context.read<AuditCubit>().load(),
                  ),
                  final AuditLoaded loaded => loaded.entries.isEmpty
                      ? EmptyState(
                          icon: filtered
                              ? Icons.filter_alt_off_outlined
                              : Icons.history,
                          title: filtered
                              ? l10n.auditEmptyFiltered
                              : l10n.auditEmpty,
                          message: filtered
                              ? l10n.auditEmptyFilteredHint
                              : l10n.auditEmptyHint,
                          action: filtered
                              ? FilledButton.tonalIcon(
                                  onPressed: () => context
                                      .read<AuditCubit>()
                                      .load(clearFilters: true),
                                  icon: const Icon(Icons.filter_alt_off_outlined),
                                  label: Text(l10n.actionClearFilters),
                                )
                              : null,
                        )
                      : RefreshIndicator(
                          onRefresh: () => context.read<AuditCubit>().load(),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: Space.xl),
                            itemCount: loaded.entries.length,
                            itemBuilder: (context, index) =>
                                _AuditTile(entry: loaded.entries[index]),
                          ),
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

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AuditEntry entry;

  static IconData _icon(String action) => switch (action) {
    'insert' => Icons.add_circle_outline,
    'delete' => Icons.delete_outline,
    _ => Icons.edit_outlined,
  };

  static (StatusTone, String Function(AppLocalizations)) _action(
    String action,
  ) => switch (action) {
    'insert' => (StatusTone.success, (l10n) => l10n.auditActionInsert),
    'delete' => (StatusTone.warning, (l10n) => l10n.auditActionDelete),
    _ => (StatusTone.neutral, (l10n) => l10n.auditActionUpdate),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (tone, label) = _action(entry.action);
    final subtitle = [
      if (entry.actor != null) entry.actor!,
      if (entry.lot != null) entry.lot!,
      Formatters.dateTime(entry.createdAt),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _ChangesDialog(entry: entry),
        ),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            _icon(entry.action),
            size: Space.md,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          '${entry.tableName}'
          '${entry.entityId == null ? '' : ' #${entry.entityId}'}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: StatusChip(label: label(l10n), tone: tone),
      ),
    );
  }
}

class _ChangesDialog extends StatelessWidget {
  const _ChangesDialog({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.auditChangesTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(child: _ChangesBody(entry: entry)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}

class _ChangesBody extends StatelessWidget {
  const _ChangesBody({required this.entry});

  final AuditEntry entry;

  static String _render(Object? value) {
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value == null ? '—' : '$value';
  }

  List<String> get _fields {
    final keys = <String>{
      ...?entry.before?.keys,
      ...?entry.after?.keys,
    };
    return keys.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final fields = _fields;
    if (fields.isEmpty) {
      return SelectableText(
        _render(entry.after ?? entry.before),
        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Space.xs),
                _ValueRow(
                  label: l10n.auditBefore,
                  value: _render(entry.before?[field]),
                ),
                const SizedBox(height: Space.xs),
                _ValueRow(
                  label: l10n.auditAfter,
                  value: _render(entry.after?[field]),
                ),
                const Divider(height: Space.lg),
              ],
            ),
          ),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
