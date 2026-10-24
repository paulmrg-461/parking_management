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
import '../application/diagnostics_cubit.dart';
import '../domain/entities/client_error_report.dart';
import '../domain/entities/diagnostics_snapshot.dart';

/// Admin operational panel: backlog counters plus the client error reports.
/// The host script `supabase/diagnostics.sh` prints the same data.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<DiagnosticsCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.diagnosticsTitle),
        actions: [
          IconButton(
            tooltip: l10n.actionRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DiagnosticsCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<DiagnosticsCubit, DiagnosticsState>(
        builder: (context, state) => switch (state) {
          DiagnosticsInitial() || DiagnosticsLoading() => const SkeletonList(),
          DiagnosticsFailure(:final message, :final failure) => ErrorState(
            message: context.l10n.errorText(message, failure),
            onRetry: () => context.read<DiagnosticsCubit>().load(),
          ),
          final DiagnosticsLoaded loaded => RefreshIndicator(
            onRefresh: () => context.read<DiagnosticsCubit>().load(),
            child: _Body(snapshot: loaded.snapshot, errors: loaded.errors),
          ),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.snapshot, required this.errors});

  final DiagnosticsSnapshot snapshot;
  final List<ClientErrorReport> errors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        _Section(
          title: l10n.diagnosticsSystem,
          icon: snapshot.hasWarnings
              ? Icons.warning_amber_outlined
              : Icons.check_circle_outline,
          rows: [
            _Metric(
              l10n.diagnosticsMigrations(snapshot.migrations),
              snapshot.lastMigrationAt == null
                  ? ''
                  : Formatters.date(snapshot.lastMigrationAt!),
            ),
            _Metric(
              l10n.diagnosticsLots(snapshot.activeLots, snapshot.lots),
              '',
            ),
            _Metric(l10n.diagnosticsOpenSessions, '${snapshot.openSessions}'),
            _Metric(
              l10n.diagnosticsStaleSessions,
              '${snapshot.staleSessions24h}',
              warning: snapshot.staleSessions24h > 0,
            ),
            _Metric(
              l10n.diagnosticsOpenShifts,
              '${snapshot.openShifts12h}',
              warning: snapshot.openShifts12h > 0,
            ),
            _Metric(
              l10n.diagnosticsPendingPayments,
              '${snapshot.pendingPassPayments}',
            ),
            _Metric(
              l10n.diagnosticsReservations,
              '${snapshot.activeReservations}',
            ),
            _Metric(
              l10n.diagnosticsIdempotency,
              '${snapshot.idempotencyKeys}',
            ),
          ],
        ),
        _Section(
          title: l10n.diagnosticsNotifications,
          icon: Icons.notifications_outlined,
          rows: [
            _Metric(
              l10n.diagnosticsPendingPush,
              '${snapshot.pendingPush}',
            ),
            _Metric(
              l10n.diagnosticsDeadPush,
              '${snapshot.deadPush}',
              warning: snapshot.deadPush > 0,
            ),
            _Metric(
              l10n.diagnosticsUnread,
              '${snapshot.unreadNotifications} / ${snapshot.totalNotifications}',
            ),
          ],
        ),
        if (snapshot.storage.isNotEmpty)
          _Section(
            title: l10n.diagnosticsStorage,
            icon: Icons.cloud_outlined,
            rows: [
              for (final usage in snapshot.storage)
                _Metric(
                  usage.bucket,
                  '${usage.objects} · ${Formatters.bytes(usage.bytes)}',
                ),
            ],
          ),
        _Section(
          title: l10n.diagnosticsErrors(errors.length),
          icon: errors.isEmpty
              ? Icons.check_circle_outline
              : Icons.bug_report_outlined,
          rows: const [],
        ),
        if (errors.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.lg),
            child: Text(l10n.diagnosticsErrorsEmpty),
          )
        else
          for (final report in errors) _ErrorTile(report: report),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Space.md),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (rows.isNotEmpty) const SizedBox(height: Space.sm),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.warning = false});

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = warning
        ? TextStyle(color: scheme.error, fontWeight: FontWeight.w600)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: Space.sm),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.report});

  final ClientErrorReport report;

  @override
  Widget build(BuildContext context) {
    final detail = [
      report.platform,
      if (report.actor != null) report.actor!,
      Formatters.dateTime(report.createdAt),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: ListTile(
        leading: const Icon(Icons.bug_report_outlined),
        title: Text(
          report.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(detail),
        onTap: () => _showDetail(context),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.diagnosticsErrorDetail),
        content: SingleChildScrollView(
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert({
              'message': report.message,
              'platform': report.platform,
              'actor': report.actor,
              'context': report.context,
              if (report.stack != null) 'stack': report.stack,
            }),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.actionClose),
          ),
        ],
      ),
    );
  }
}
