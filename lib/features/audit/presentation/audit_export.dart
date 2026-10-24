import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/l10n/l10n.dart';
import '../../../core/receipt/pdf_table.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/audit_entry.dart';

/// CSV of the audit entries (RFC 4180 quoting), ready for a spreadsheet.
String auditCsv(List<AuditEntry> entries) {
  String cell(Object? value) {
    final text = (value ?? '').toString();
    return text.contains(RegExp('[",\n]'))
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  final lines = <String>[
    'created_at,actor,action,table,entity_id,lot,changed_fields',
    for (final entry in entries)
      [
        entry.createdAt.toIso8601String(),
        cell(entry.actor),
        entry.action,
        entry.tableName,
        cell(entry.entityId),
        cell(entry.lot),
        cell(entry.changes.keys.join(' ')),
      ].join(','),
  ];
  return lines.join('\n');
}

/// Shareable PDF of the audit entries currently on screen.
Future<Uint8List> buildAuditPdf({
  required AppLocalizations l10n,
  required List<AuditEntry> entries,
  String? subtitle,
}) {
  final doc = pw.Document();
  final builder = PdfDocumentBuilder(
    title: l10n.auditTitle,
    subtitle: subtitle,
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
          for (final entry in entries)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${Formatters.dateTime(entry.createdAt)} · '
                    '${entry.actor ?? '-'} · ${entry.action}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${entry.tableName}'
                    '${entry.entityId == null ? '' : ' #${entry.entityId}'}'
                    '${entry.lot == null ? '' : ' · ${entry.lot}'}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  if (entry.changes.isNotEmpty)
                    pw.Text(
                      entry.changes.keys.join(', '),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                ],
              ),
            ),
        ]),
      ],
    ),
  );
  return doc.save();
}

String auditPdfFileName(DateTime now) =>
    'auditoria-${now.year}-${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}.pdf';
