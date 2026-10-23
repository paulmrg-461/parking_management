import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/pdf_table.dart';
import '../../../core/utils/cop_formatter.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/revenue_report.dart';

/// Builds the shareable PDF for the revenue report (active lot, or every site
/// when [allLots] was requested). Pure: no I/O, so it can be unit-tested.
Future<Uint8List> buildRevenueReportPdf({
  required AppLocalizations l10n,
  required RevenueReport revenue,
  required String headline,
  String? lotName,
}) {
  final doc = pw.Document();
  final builder = PdfDocumentBuilder(
    title: headline,
    subtitle: lotName == null
        ? '${Formatters.date(revenue.startDate)} — ${Formatters.date(revenue.endDate)}'
        : '$lotName · ${Formatters.date(revenue.startDate)} — '
              '${Formatters.date(revenue.endDate)}',
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      build: (context) => [
        builder.build([
          PdfDocumentBuilder.row(
            l10n.reportsTotalRevenue,
            CopFormatter.format(revenue.total),
            bold: true,
          ),
          if (revenue.totalDiscounts > 0)
            PdfDocumentBuilder.row(
              l10n.reportsTotalDiscounts,
              '-${CopFormatter.format(revenue.totalDiscounts)}',
            ),
          if (revenue.discountedSessions > 0)
            PdfDocumentBuilder.row(
              l10n.reportsDiscountLog,
              '${revenue.discountedSessions}',
            ),
          if (revenue.passRevenue > 0)
            PdfDocumentBuilder.row(
              l10n.reportsPassRevenue,
              CopFormatter.format(revenue.passRevenue),
            ),
          if (revenue.byLot.isNotEmpty)
            PdfDocumentBuilder.section(l10n.reportsByLot, [
              for (final lot in revenue.byLot)
                PdfDocumentBuilder.row(
                  lot.lotName,
                  CopFormatter.format(lot.amount),
                ),
            ]),
          PdfDocumentBuilder.section(l10n.reportsRevenueByDay, [
            for (final day in revenue.byDay)
              PdfDocumentBuilder.row(
                Formatters.date(day.date),
                CopFormatter.format(day.amount),
              ),
          ]),
          PdfDocumentBuilder.section(l10n.reportsRevenueByCategory, [
            for (final category in revenue.byCategory)
              PdfDocumentBuilder.row(
                category.categoryName,
                CopFormatter.format(category.amount),
              ),
          ]),
          if (revenue.byPayment.isNotEmpty)
            PdfDocumentBuilder.section(l10n.reportsRevenueByPayment, [
              for (final payment in revenue.byPayment)
                PdfDocumentBuilder.row(
                  payment.paymentMethod,
                  CopFormatter.format(payment.amount),
                ),
            ]),
          if (revenue.discountAudit.isNotEmpty)
            PdfDocumentBuilder.section(l10n.reportsDiscountLog, [
              for (final discount in revenue.discountAudit)
                PdfDocumentBuilder.row(
                  '${discount.plate} · ${Formatters.date(discount.discountAt)}',
                  '-${CopFormatter.format(discount.discountAmount)}',
                ),
            ]),
        ]),
      ],
    ),
  );
  return doc.save();
}
