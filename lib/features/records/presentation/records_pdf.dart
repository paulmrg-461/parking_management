import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/pdf_table.dart';
import '../../../core/utils/cop_formatter.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/session_record.dart';

/// Shareable PDF of the filtered records: summary plus one row per session.
/// Pure (no I/O), so it can be unit-tested.
Future<Uint8List> buildRecordsPdf({
  required AppLocalizations l10n,
  required List<SessionRecord> records,
  String? plate,
  DateTime? from,
  DateTime? to,
}) {
  final doc = pw.Document();
  final charged = records.fold<int>(0, (sum, item) => sum + item.amountCharged);
  final filters = [
    if (plate != null && plate.trim().isNotEmpty)
      '${l10n.plateLabel}: $plate',
    if (from != null && to != null)
      '${Formatters.date(from)} — ${Formatters.date(to)}',
    if (from == null && to == null) l10n.recordsRangeAll,
  ].join(' · ');
  final builder = PdfDocumentBuilder(
    title: l10n.recordsTitle,
    subtitle: filters,
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
            l10n.recordsCount(records.length),
            CopFormatter.format(charged),
            bold: true,
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: [
              l10n.plateLabel,
              l10n.recordsEntry,
              l10n.recordsExit,
              l10n.recordsDuration,
              l10n.recordsAmount,
            ],
            data: [
              for (final record in records)
                [
                  record.plate,
                  Formatters.dateTime(record.entryTime),
                  record.exitTime == null
                      ? l10n.statusOpen
                      : Formatters.dateTime(record.exitTime!),
                  Formatters.duration(l10n, record.duration),
                  CopFormatter.format(record.amountCharged),
                ],
            ],
            headerStyle: const pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1),
            },
          ),
        ]),
      ],
    ),
  );
  return doc.save();
}
