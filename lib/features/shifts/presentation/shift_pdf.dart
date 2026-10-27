import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/pdf_table.dart';
import '../../../core/utils/cop_formatter.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/shift_summary.dart';

/// Shareable PDF of one shift's reconciliation ("arqueo de caja").
Future<Uint8List> buildShiftPdf({
  required AppLocalizations l10n,
  required ShiftSummary shift,
  String? lotName,
}) {
  final doc = pw.Document();
  final builder = PdfDocumentBuilder(
    title: '${l10n.shiftTitle} #${shift.id}',
    subtitle: [
      ?lotName,
      '${Formatters.dateTime(shift.openedAt)}'
          '${shift.closedAt == null ? '' : ' — ${Formatters.dateTime(shift.closedAt!)}'}',
    ].join(' · '),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        builder.build([
          PdfDocumentBuilder.row(
            l10n.shiftOpeningFloat,
            CopFormatter.format(shift.openingFloat),
          ),
          PdfDocumentBuilder.section(l10n.shiftSales, [
            PdfDocumentBuilder.row(
              l10n.shiftSessionCount,
              '${shift.sessionCount}',
            ),
            PdfDocumentBuilder.row(
              l10n.shiftSales,
              CopFormatter.format(shift.revenue),
              bold: true,
            ),
            PdfDocumentBuilder.row(
              l10n.shiftCashSales,
              CopFormatter.format(shift.cashSales),
            ),
            PdfDocumentBuilder.row(
              l10n.shiftCardSales,
              CopFormatter.format(shift.cardSales),
            ),
            PdfDocumentBuilder.row(
              l10n.shiftTransferSales,
              CopFormatter.format(shift.transferSales),
            ),
            PdfDocumentBuilder.row(
              l10n.shiftPassSales,
              CopFormatter.format(shift.passSales),
            ),
            if (shift.passCashSales > 0)
              PdfDocumentBuilder.row(
                l10n.reportsPassRevenue,
                CopFormatter.format(shift.passCashSales),
              ),
            if (shift.discounts > 0)
              PdfDocumentBuilder.row(
                l10n.shiftDiscounts,
                '-${CopFormatter.format(shift.discounts)}',
              ),
          ]),
          PdfDocumentBuilder.section(l10n.shiftCashMovements, [
            PdfDocumentBuilder.row(
              l10n.shiftWithdrawals,
              CopFormatter.format(shift.withdrawals),
            ),
            PdfDocumentBuilder.row(
              l10n.shiftDeposits,
              CopFormatter.format(shift.deposits),
            ),
          ]),
          PdfDocumentBuilder.section(l10n.shiftReconciliation, [
            PdfDocumentBuilder.row(
              l10n.shiftExpectedCash,
              CopFormatter.format(shift.expectedCash),
            ),
            PdfDocumentBuilder.row(
              l10n.shiftCountedCash,
              CopFormatter.format(shift.countedCash ?? 0),
            ),
            PdfDocumentBuilder.row(
              l10n.shiftDifference,
              CopFormatter.format(shift.difference ?? 0),
              bold: true,
            ),
          ]),
          if (shift.notes != null && shift.notes!.trim().isNotEmpty)
            PdfDocumentBuilder.section(l10n.shiftNotesTitle, [
              pw.Text(shift.notes!),
            ]),
        ]),
      ],
    ),
  );
  return doc.save();
}
