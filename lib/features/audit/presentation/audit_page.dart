import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../application/audit_cubit.dart';
import '../domain/entities/audit_entry.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.auditTitle),
        actions: [
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
          final table = state is AuditLoaded ? state.table : null;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.sm,
                  Space.md,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: table,
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
                    if (state is AuditLoaded &&
                        (state.from != null || state.table != null))
                      TextButton(
                        onPressed: () => context
                            .read<AuditCubit>()
                            .load(clearFilters: true),
                        child: Text(l10n.shiftHistoryClearFilter),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: switch (state) {
                  AuditInitial() || AuditLoading() => const SkeletonList(),
                  AuditFailure(:final message, :final failure) => ErrorState(
                    message: context.l10n.errorText(message, failure),
                    onRetry: () => context.read<AuditCubit>().load(),
                  ),
                  final AuditLoaded loaded => loaded.entries.isEmpty
                      ? Center(child: Text(l10n.auditEmpty))
                      : RefreshIndicator(
                          onRefresh: () => context.read<AuditCubit>().load(),
                          child: ListView.builder(
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

  IconData get _icon => switch (entry.action) {
    'insert' => Icons.add_circle_outline,
    'delete' => Icons.delete_outline,
    _ => Icons.edit_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = [
      if (entry.actor != null) entry.actor!,
      if (entry.lot != null) entry.lot!,
      Formatters.dateTime(entry.createdAt),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
      child: ListTile(
        leading: Icon(_icon),
        title: Text(
          '${entry.tableName}'
          '${entry.entityId == null ? '' : ' #${entry.entityId}'}',
        ),
        subtitle: Text(detail),
        trailing: Text(entry.action),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l10n.auditChangesTitle),
            content: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert({
                  if (entry.before != null) 'before': entry.before,
                  if (entry.after != null) 'after': entry.after,
                }),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.actionClose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
