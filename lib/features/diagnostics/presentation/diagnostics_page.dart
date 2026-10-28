import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/diagnostics_cubit.dart';
import '../domain/entities/client_error_report.dart';
import '../domain/entities/diagnostics_snapshot.dart';
import '../domain/entities/whatsapp_message.dart';

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
          DiagnosticsInitial() ||
          DiagnosticsLoading() => const SkeletonCardList(itemCount: 3),
          DiagnosticsFailure(:final message, :final failure) => ErrorState(
            message: context.l10n.errorText(message, failure),
            onRetry: () => context.read<DiagnosticsCubit>().load(),
          ),
          final DiagnosticsLoaded loaded => RefreshIndicator(
            onRefresh: () => context.read<DiagnosticsCubit>().load(),
            child: _Body(
              snapshot: loaded.snapshot,
              errors: loaded.errors,
              whatsapp: loaded.whatsapp,
            ),
          ),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.snapshot,
    required this.errors,
    required this.whatsapp,
  });

  final DiagnosticsSnapshot snapshot;
  final List<ClientErrorReport> errors;
  final List<WhatsappMessage> whatsapp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final alerts =
        errors.length +
        snapshot.staleSessions24h +
        snapshot.deadPush +
        snapshot.whatsappFailed;
    return ListView(
      padding: const EdgeInsets.all(Space.md),
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricCard(
                  icon: Icons.directions_car_outlined,
                  label: l10n.diagnosticsOpenNow,
                  value: '${snapshot.openSessions}',
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: MetricCard(
                  icon: Icons.outbox_outlined,
                  label: l10n.diagnosticsPendingQueue,
                  value: '${snapshot.pendingPush + snapshot.whatsappPending}',
                  tone: snapshot.pendingPush + snapshot.whatsappPending > 0
                      ? MetricTone.warning
                      : MetricTone.neutral,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: MetricCard(
                  icon: Icons.health_and_safety_outlined,
                  label: l10n.diagnosticsAlerts,
                  value: '$alerts',
                  tone: alerts > 0 ? MetricTone.danger : MetricTone.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
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
        _Section(
          title: l10n.diagnosticsWhatsapp,
          icon: snapshot.whatsappFailed > 0
              ? Icons.warning_amber_outlined
              : Icons.chat_outlined,
          rows: [
            _Metric(
              l10n.diagnosticsWhatsappPending,
              '${snapshot.whatsappPending}',
            ),
            _Metric(
              l10n.diagnosticsWhatsappFailedCount,
              '${snapshot.whatsappFailed}',
              warning: snapshot.whatsappFailed > 0,
            ),
            _Metric(
              l10n.diagnosticsWhatsappSent,
              '${snapshot.whatsappSent24h}',
            ),
          ],
        ),
        if (whatsapp.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Text(l10n.diagnosticsWhatsappEmpty),
          )
        else
          for (final message in whatsapp) _WhatsappTile(message: message),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(icon: icon, title: title),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.sm,
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < rows.length; index++) ...[
                      if (index > 0) const Divider(height: 1),
                      rows[index],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
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
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: Space.sm),
          if (warning)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: StatusChip(
                label: context.l10n.diagnosticsAlerts,
                tone: StatusTone.warning,
              ),
            ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsappTile extends StatelessWidget {
  const _WhatsappTile({required this.message});

  final WhatsappMessage message;

  IconData get _icon => switch (message.status) {
    'sent' => Icons.check_circle_outline,
    'failed' => Icons.error_outline,
    _ => Icons.schedule,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = [
      if (message.actor != null) message.actor!,
      if (message.lot != null) message.lot!,
      Formatters.dateTime(message.createdAt),
      if (message.attempts > 0) l10n.diagnosticsWhatsappAttempts(message.attempts),
    ].join(' · ');
    final scheme = Theme.of(context).colorScheme;
    final failed = message.status == 'failed';
    return Card(
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: failed
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          child: Icon(
            _icon,
            size: 20,
            color: failed ? scheme.onErrorContainer : scheme.onSurfaceVariant,
          ),
        ),
        title: Text('${message.template} · ${message.toPhone}'),
        subtitle: Text(
          message.error == null || message.error!.isEmpty
              ? subtitle
              : '${message.error}\n$subtitle',
        ),
        isThreeLine: message.error != null && message.error!.isNotEmpty,
        trailing: failed
            ? Icon(
                Icons.error_outline,
                color: scheme.error,
                semanticLabel: context.l10n.diagnosticsWhatsappFailedCount,
              )
            : null,
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
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          child: Icon(
            Icons.bug_report_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
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
