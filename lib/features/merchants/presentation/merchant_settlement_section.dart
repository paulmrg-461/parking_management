import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/pdf_share.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../application/merchant_settlement_cubit.dart';
import '../domain/entities/merchant_settlement.dart';
import 'merchant_settlement_csv.dart';
import 'merchant_settlement_pdf.dart';

/// Settlement of the selected month: rows, totals and the exports.
class MerchantSettlementSection extends StatefulWidget {
  const MerchantSettlementSection({super.key});

  @override
  State<MerchantSettlementSection> createState() =>
      _MerchantSettlementSectionState();
}

class _MerchantSettlementSectionState extends State<MerchantSettlementSection> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month);
    _end = DateTime(now.year, now.month + 1, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MerchantSettlementCubit>().load(start: _start, end: _end);
      }
    });
  }

  Future<void> _copyCsv(MerchantSettlement settlement) async {
    await Clipboard.setData(
      ClipboardData(text: merchantSettlementCsv(settlement)),
    );
    if (mounted) {
      showInfoSnack(context, context.l10n.reportsCsvCopied);
    }
  }

  Future<void> _sharePdf(MerchantSettlement settlement) async {
    final l10n = context.l10n;
    final bytes = await buildMerchantSettlementPdf(
      l10n: l10n,
      settlement: settlement,
    );
    if (!mounted) {
      return;
    }
    await sharePdfBytes(
      context,
      bytes: bytes,
      filename: pdfFileName('liquidacion', settlement.from, settlement.to),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<MerchantSettlementCubit, MerchantSettlementState>(
      builder: (context, state) => switch (state) {
        MerchantSettlementInitial() || MerchantSettlementLoading() =>
          const SkeletonList(),
        MerchantSettlementFailure(:final failure) => ErrorState(
          message: l10n.failure(failure),
          onRetry: () => context.read<MerchantSettlementCubit>().retry(),
        ),
        MerchantSettlementLoaded(:final settlement) => ListView(
          padding: const EdgeInsets.all(Space.md),
          children: [
            SectionHeader(
              icon: Icons.receipt_long_outlined,
              title: l10n.merchantSettlementTitle,
              subtitle:
                  '${Formatters.date(settlement.from)} - '
                  '${Formatters.date(settlement.to)}',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconButton(
                    key: const Key('merchant_settlement_csv'),
                    icon: Icons.copy_all_outlined,
                    tooltip: l10n.reportsExportCsv,
                    onPressed: () => _copyCsv(settlement),
                  ),
                  AppIconButton(
                    key: const Key('merchant_settlement_pdf'),
                    icon: Icons.picture_as_pdf_outlined,
                    tooltip: l10n.actionExportPdf,
                    onPressed: () => _sharePdf(settlement),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            if (!settlement.hasActivity)
              EmptyState(
                message: l10n.merchantSettlementEmpty,
                icon: Icons.storefront_outlined,
              )
            else ...[
              for (final row in settlement.rows) _RowCard(row: row),
              const Divider(),
              _RowCard(row: settlement.totals, bold: true),
            ],
          ],
        ),
      },
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, this.bold = false});

  final MerchantSettlementRow row;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.name,
              style: bold
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.md,
              runSpacing: Space.xs,
              children: [
                Text('${l10n.merchantSettlementValidations}: ${row.validations}'),
                Text('${l10n.merchantSettlementApplied}: ${row.applied}'),
                Text('${l10n.merchantSettlementForfeited}: ${row.forfeited}'),
                Text('${l10n.merchantSettlementRevoked}: ${row.revoked}'),
                Text(
                  '${l10n.merchantSettlementDiscounted}: '
                  '${Formatters.money(row.discountedAmount)}',
                ),
                Text(
                  '${l10n.merchantSettlementOwed}: '
                  '${Formatters.money(row.amountOwed)}',
                ),
                Text(
                  '${l10n.merchantSettlementCourtesy}: '
                  '${Formatters.money(row.courtesyAmount)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
