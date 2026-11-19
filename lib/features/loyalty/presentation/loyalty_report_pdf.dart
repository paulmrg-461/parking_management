import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/l10n/l10n.dart';
import '../../../core/money/money.dart';
import '../../../core/receipt/pdf_table.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/loyalty_report.dart';

/// Shareable PDF of the loyalty report. Pure: no I/O.
Future<Uint8List> buildLoyaltyReportPdf({
  required AppLocalizations l10n,
  required LoyaltyReport report,
  required String headline,
  String? lotName,
}) {
  final doc = pw.Document();
  final builder = PdfDocumentBuilder(
    title: headline,
    subtitle: lotName == null
        ? Formatters.pdfDateRange(report.startDate, report.endDate)
        : '$lotName · ${Formatters.pdfDateRange(report.startDate, report.endDate)}',
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        builder.build([
          PdfDocumentBuilder.row(
            l10n.loyaltyReportMembers,
            '${report.members} (${report.activeMembers})',
          ),
          PdfDocumentBuilder.row(
            l10n.loyaltyReportCounted,
            '${report.counted}',
          ),
          PdfDocumentBuilder.row(
            l10n.loyaltyReportSkipped,
            '${report.skipped}',
          ),
          PdfDocumentBuilder.row(
            l10n.loyaltyReportEarned,
            '${report.earned}',
          ),
          PdfDocumentBuilder.row(
            l10n.loyaltyReportRedeemed,
            '${report.redeemed}',
          ),
          PdfDocumentBuilder.row(
            l10n.loyaltyReportDiscount,
            Money.format(report.discountGiven),
          ),
          PdfDocumentBuilder.section(l10n.loyaltyReportTopPlates, [
            for (final item in report.topPlates)
              PdfDocumentBuilder.row(
                item.plate,
                '${item.counted} · ${Money.format(item.discount)}',
              ),
          ]),
        ]),
      ],
    ),
  );
  return doc.save();
}
