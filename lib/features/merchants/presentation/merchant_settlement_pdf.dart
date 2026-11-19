import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/pdf_table.dart';
import '../../../core/utils/cop_formatter.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/merchant_settlement.dart';

/// Shareable settlement PDF (one row per merchant plus the totals).
Future<Uint8List> buildMerchantSettlementPdf({
  required AppLocalizations l10n,
  required MerchantSettlement settlement,
  String? lotName,
}) {
  final doc = pw.Document();
  final builder = PdfDocumentBuilder(
    title: l10n.merchantSettlementPdfTitle,
    subtitle: [
      ?lotName,
      Formatters.pdfDateRange(settlement.from, settlement.to),
    ].join(' · '),
  );

  pw.Widget merchantRow(MerchantSettlementRow row, {bool bold = false}) =>
      PdfDocumentBuilder.row(
        row.name,
        '${row.validations} · ${CopFormatter.format(row.discountedAmount)} · '
        '${CopFormatter.format(row.amountOwed)}',
        bold: bold,
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        builder.build([
          PdfDocumentBuilder.section(l10n.merchantSettlementTitle, [
            for (final row in settlement.rows) merchantRow(row),
            pw.Divider(),
            merchantRow(settlement.totals, bold: true),
          ]),
        ]),
      ],
    ),
  );
  return doc.save();
}
