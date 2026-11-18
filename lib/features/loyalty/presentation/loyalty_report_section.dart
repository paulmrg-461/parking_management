import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/receipt/pdf_share.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../domain/entities/loyalty_report.dart';
import 'loyalty_report_csv.dart';
import 'loyalty_report_pdf.dart';

/// Report tab: figures, skip reasons, top plates and the export actions.
class LoyaltyReportSection extends StatefulWidget {
  const LoyaltyReportSection({
    super.key,
    required this.report,
    required this.onRefresh,
    this.lotName,
  });

  final LoyaltyReport? report;
  final Future<void> Function(DateTime start, DateTime end) onRefresh;
  final String? lotName;

  @override
  State<LoyaltyReportSection> createState() => _LoyaltyReportSectionState();
}

class _LoyaltyReportSectionState extends State<LoyaltyReportSection> {
  late DateTime _start = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _end = DateTime.now();
  bool _busy = false;

  Future<void> _pick({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await widget.onRefresh(_start, _end);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyCsv(LoyaltyReport report) async {
    await Clipboard.setData(ClipboardData(text: loyaltyReportCsv(report)));
    if (mounted) {
      showInfoSnack(context, context.l10n.loyaltyCsvCopied);
    }
  }

  Future<void> _sharePdf(LoyaltyReport report) async {
    final bytes = await buildLoyaltyReportPdf(
      l10n: context.l10n,
      report: report,
      headline: context.l10n.loyaltyTitle,
      lotName: widget.lotName,
    );
    if (!mounted) {
      return;
    }
    await sharePdfBytes(
      context,
      bytes: bytes,
      filename: pdfFileName('fidelizacion', report.startDate, report.endDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final report = widget.report;
    return ListView(
      key: const Key('loyalty_report'),
      padding: const EdgeInsets.all(Space.md),
      children: [
        SectionHeader(
          icon: Icons.insights_outlined,
          title: l10n.loyaltyTabReport,
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pick(start: true),
              icon: const Icon(Icons.event_outlined),
              label: Text(_date(_start)),
            ),
            OutlinedButton.icon(
              onPressed: () => _pick(start: false),
              icon: const Icon(Icons.event_available_outlined),
              label: Text(_date(_end)),
            ),
            FilledButton.icon(
              key: const Key('loyalty_report_refresh'),
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.loyaltyRefreshReport),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        if (report == null)
          Text(l10n.loyaltyReportEmpty)
        else ...[
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              _metric(
                l10n.loyaltyReportMembers,
                '${report.members} (${report.activeMembers})',
                Icons.people_outline,
              ),
              _metric(
                l10n.loyaltyReportCounted,
                '${report.counted}',
                Icons.check_circle_outline,
              ),
              _metric(
                l10n.loyaltyReportSkipped,
                '${report.skipped}',
                Icons.remove_circle_outline,
              ),
              _metric(
                l10n.loyaltyReportEarned,
                '${report.earned}',
                Icons.card_giftcard_outlined,
              ),
              _metric(
                l10n.loyaltyReportRedeemed,
                '${report.redeemed}',
                Icons.redeem_outlined,
              ),
              _metric(
                l10n.loyaltyReportDiscount,
                Money.format(report.discountGiven),
                Icons.payments_outlined,
              ),
            ],
          ),
          if (report.skippedByReason.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            SectionHeader(
              icon: Icons.info_outline,
              title: l10n.loyaltyReportSkipped,
            ),
            for (final item in report.skippedByReason)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_skipLabel(context, item.reason)),
                trailing: Text('${item.count}'),
              ),
          ],
          if (report.topPlates.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            SectionHeader(
              icon: Icons.star_outline,
              title: l10n.loyaltyReportTopPlates,
            ),
            for (final item in report.topPlates)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.plate),
                subtitle: Text(
                  l10n.loyaltyReportCounted,
                ),
                trailing: Text(
                  '${item.counted} · ${Money.format(item.discount)}',
                ),
              ),
          ],
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              OutlinedButton.icon(
                key: const Key('loyalty_copy_csv'),
                onPressed: () => _copyCsv(report),
                icon: const Icon(Icons.copy_all_outlined),
                label: Text(l10n.loyaltyCopyCsv),
              ),
              OutlinedButton.icon(
                key: const Key('loyalty_share_pdf'),
                onPressed: () => _sharePdf(report),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(l10n.loyaltySharePdf),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _metric(String label, String value, IconData icon) => SizedBox(
    width: 180,
    child: MetricCard(label: label, value: value, icon: icon),
  );

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _skipLabel(BuildContext context, String reason) {
    final l10n = context.l10n;
    return switch (reason) {
      'pass' => l10n.loyaltySkip_pass,
      'lost_ticket' => l10n.loyaltySkip_lost_ticket,
      'exempt' => l10n.loyaltySkip_exempt,
      'below_amount' => l10n.loyaltySkip_below_amount,
      'below_minutes' => l10n.loyaltySkip_below_minutes,
      'same_day' => l10n.loyaltySkip_same_day,
      'reward_redeemed' => l10n.loyaltySkip_reward_redeemed,
      _ => l10n.loyaltySkip_error,
    };
  }
}
