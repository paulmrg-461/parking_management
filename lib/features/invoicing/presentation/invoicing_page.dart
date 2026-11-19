import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/network/connectivity_cubit.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/invoicing_cubit.dart';
import '../domain/entities/fiscal_document.dart';
import '../domain/entities/fiscal_resolution.dart';
import '../domain/entities/fiscal_settings.dart';
import 'widgets/fiscal_resolution_dialog.dart';
import 'widgets/fiscal_status_chip.dart';

/// Admin screen: issuer data, numbering resolutions and the document outbox.
class InvoicingPage extends StatefulWidget {
  const InvoicingPage({super.key});

  @override
  State<InvoicingPage> createState() => _InvoicingPageState();
}

class _InvoicingPageState extends State<InvoicingPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<InvoicingCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoicingTitle)),
      body: BlocConsumer<InvoicingCubit, InvoicingState>(
        listenWhen: (previous, current) =>
            current is InvoicingLoaded &&
            previous is InvoicingLoaded &&
            current.submission != previous.submission,
        listener: (context, state) {
          if (state is! InvoicingLoaded) {
            return;
          }
          final submission = state.submission;
          if (submission is SubmissionSucceeded) {
            showInfoSnack(context, l10n.invoicingDocuments);
          } else if (submission is SubmissionFailed) {
            final failed = submission;
            showErrorSnack(
              context,
              l10n.errorText(failed.message, failed.failure),
            );
          }
        },
        builder: (context, state) => switch (state) {
          InvoicingInitial() || InvoicingLoading() => const SkeletonList(),
          InvoicingFailure(:final message, :final failure) => Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: ErrorState(
              message: l10n.errorText(message, failure),
              onRetry: context.read<InvoicingCubit>().load,
            ),
          ),
          InvoicingLoaded(
            :final settings,
            :final resolutions,
            :final documents,
            :final statusFilter,
            :final total,
          ) =>
            _Loaded(
              settings: settings,
              resolutions: resolutions,
              documents: documents,
              statusFilter: statusFilter,
              total: total,
            ),
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.settings,
    required this.resolutions,
    required this.documents,
    required this.statusFilter,
    required this.total,
  });

  final FiscalSettings settings;
  final List<FiscalResolution> resolutions;
  final List<FiscalDocument> documents;
  final FiscalStatus? statusFilter;
  final int total;

  bool _online(BuildContext context) {
    try {
      return context.read<ConnectivityCubit>().state;
    } on ProviderNotFoundException {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<InvoicingCubit>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.md,
        Space.md,
        Space.xxl,
      ),
      children: [
        if (!_online(context))
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Text(
              l10n.invoicingOnlineOnly,
              key: const Key('invoicing_offline'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SectionHeader(
          icon: Icons.business_outlined,
          title: l10n.invoicingSettings,
          subtitle: l10n.invoicingPricesIncludeTax,
        ),
        const SizedBox(height: Space.sm),
        _SettingsCard(settings: settings),
        const SizedBox(height: Space.md),
        SectionHeader(
          icon: Icons.confirmation_number_outlined,
          title: l10n.invoicingResolutions,
          action: TextButton.icon(
            key: const Key('invoicing_resolution_add'),
            onPressed: () async {
              final resolution = await showFiscalResolutionDialog(context);
              if (resolution != null && context.mounted) {
                await cubit.saveResolution(resolution);
              }
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.invoicingResolutionAdd),
          ),
        ),
        if (resolutions.isEmpty)
          Text(l10n.invoicingEmpty)
        else
          for (final resolution in resolutions)
            Card(
              key: Key('fiscal_resolution_${resolution.id}'),
              margin: const EdgeInsets.only(bottom: Space.sm),
              child: ListTile(
                leading: const Icon(Icons.confirmation_number_outlined),
                title: Text(
                  '${resolution.prefix} · ${resolution.resolutionNumber}',
                ),
                subtitle: Text(
                  '${resolution.docType.wire} · '
                  '${l10n.invoicingResolutionRemaining(resolution.remaining)}',
                ),
                trailing: resolution.active
                    ? const Icon(Icons.check_circle_outline)
                    : null,
              ),
            ),
        const SizedBox(height: Space.md),
        SectionHeader(
          icon: Icons.receipt_long_outlined,
          title: l10n.invoicingDocuments,
          subtitle: '$total',
        ),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            ChoiceChip(
              key: const Key('invoicing_filter_all'),
              label: Text(l10n.invoicingDocuments),
              selected: statusFilter == null,
              onSelected: (_) => cubit.filterBy(null),
            ),
            for (final status in FiscalStatus.values)
              ChoiceChip(
                key: Key('invoicing_filter_${status.wire}'),
                label: Text(FiscalStatusChip.label(status, l10n)),
                selected: statusFilter == status,
                onSelected: (_) => cubit.filterBy(status),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        if (documents.isEmpty)
          EmptyState(
            title: l10n.invoicingDocuments,
            message: l10n.invoicingEmpty,
            icon: Icons.receipt_long_outlined,
            action: FilledButton.icon(
              key: const Key('invoicing_empty_cta'),
              onPressed: () async {
                final resolution = await showFiscalResolutionDialog(context);
                if (resolution != null && context.mounted) {
                  await cubit.saveResolution(resolution);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.invoicingResolutionAdd),
            ),
          )
        else
          for (final document in documents) _DocumentCard(document: document),
        if (documents.length < total)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: OutlinedButton(
              key: const Key('invoicing_load_more'),
              onPressed: cubit.loadMore,
              child: Text(l10n.actionLoadMore),
            ),
          ),
      ],
    );
  }
}

class _SettingsCard extends StatefulWidget {
  const _SettingsCard({required this.settings});

  final FiscalSettings settings;

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  late FiscalMode _mode = widget.settings.mode;
  late final _nit = TextEditingController(text: widget.settings.issuerNit);
  late final _legal = TextEditingController(
    text: widget.settings.issuerLegalName,
  );
  late final _municipality = TextEditingController(
    text: widget.settings.municipalityCode,
  );
  late final _rate = TextEditingController(text: '${widget.settings.taxRateBps}');

  @override
  void dispose() {
    _nit.dispose();
    _legal.dispose();
    _municipality.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _save() {
    final rate = int.tryParse(_rate.text.trim()) ?? -1;
    if (rate < 0 || rate > 10000) {
      showErrorSnack(context, context.l10n.errorInvalidData);
      return;
    }
    unawaited(
      context.read<InvoicingCubit>().saveSettings(
        FiscalSettings(
          mode: _mode,
          issuerNit: _nit.text.trim().isEmpty ? null : _nit.text.trim(),
          issuerLegalName:
              _legal.text.trim().isEmpty ? null : _legal.text.trim(),
          taxRegime: widget.settings.taxRegime,
          taxRateBps: rate,
          municipalityCode: _municipality.text.trim().isEmpty
              ? null
              : _municipality.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const Key('invoicing_settings'),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<FiscalMode>(
              key: const Key('invoicing_mode'),
              isExpanded: true,
              initialValue: _mode,
              decoration: InputDecoration(labelText: l10n.invoicingMode),
              items: [
                DropdownMenuItem(
                  value: FiscalMode.off,
                  child: Text(l10n.invoicingModeOff),
                ),
                DropdownMenuItem(
                  value: FiscalMode.onRequest,
                  child: Text(l10n.invoicingModeOnRequest),
                ),
                DropdownMenuItem(
                  value: FiscalMode.always,
                  child: Text(l10n.invoicingModeAlways),
                ),
              ],
              onChanged: (value) => setState(() => _mode = value ?? _mode),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('invoicing_nit'),
              controller: _nit,
              decoration: InputDecoration(labelText: l10n.invoicingNit),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('invoicing_legal_name'),
              controller: _legal,
              decoration: InputDecoration(labelText: l10n.invoicingLegalName),
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                SizedBox(
                  width: 170,
                  child: TextField(
                    key: const Key('invoicing_municipality'),
                    controller: _municipality,
                    decoration: InputDecoration(
                      labelText: l10n.invoicingMunicipality,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    key: const Key('invoicing_tax_rate'),
                    controller: _rate,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.invoicingTaxRate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('invoicing_save_settings'),
                onPressed: _save,
                child: Text(l10n.actionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});

  final FiscalDocument document;

  Future<void> _credit(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CreditReasonDialog(),
    );
    if (reason != null && context.mounted) {
      await context.read<InvoicingCubit>().requestCreditNote(
        document.id,
        reason,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: Key('fiscal_document_${document.id}'),
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: Padding(
        padding: const EdgeInsets.all(Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    document.fullNumber,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                FiscalStatusChip(status: document.status),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              '${document.docType.wire} · ${Money.format(document.total)}'
              '${document.voided ? ' · anulado' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (document.customerName != null)
              Text(
                '${document.customerName} '
                '${document.customerDocType?.wire ?? ''} '
                '${document.customerDocNumber ?? ''}',
                style: theme.textTheme.bodySmall,
              ),
            if (document.cufe != null)
              Text(document.cufe!, style: theme.textTheme.bodySmall),
            if (document.rejectionReason != null)
              Text(
                document.rejectionReason!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            if (document.status.canRetry || document.status.isAccepted)
              Wrap(
                spacing: Space.sm,
                children: [
                  if (document.status.canRetry)
                    TextButton.icon(
                      key: Key('invoice_retry_${document.id}'),
                      onPressed: () =>
                          context.read<InvoicingCubit>().retry(document.id),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.invoicingRetry),
                    ),
                  if (document.status.isAccepted && !document.voided)
                    TextButton.icon(
                      key: Key('invoice_credit_${document.id}'),
                      onPressed: () => _credit(context),
                      icon: const Icon(Icons.undo),
                      label: Text(l10n.invoicingCreditNote),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CreditReasonDialog extends StatefulWidget {
  const _CreditReasonDialog();

  @override
  State<_CreditReasonDialog> createState() => _CreditReasonDialogState();
}

class _CreditReasonDialogState extends State<_CreditReasonDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _reason.text.trim();
    if (value.length < 3 || value.length > 200) {
      setState(() => _error = context.l10n.errorInvalidData);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('invoice_credit_dialog'),
      title: Text(l10n.invoicingCreditNote),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('invoice_credit_reason'),
              controller: _reason,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l10n.invoicingCreditReason,
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('invoice_credit_save'),
          onPressed: _submit,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
