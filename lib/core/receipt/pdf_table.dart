import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared look for the exported PDFs (reports and shift reconciliation):
/// a title, a subtitle line and label/value rows with a light divider.
class PdfDocumentBuilder {
  PdfDocumentBuilder({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  pw.Widget build(List<pw.Widget> children) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      if (subtitle != null) ...[
        pw.SizedBox(height: 2),
        pw.Text(subtitle!, style: const pw.TextStyle(fontSize: 10)),
      ],
      pw.SizedBox(height: 10),
      pw.Divider(color: PdfColors.grey400),
      ...children,
    ],
  );

  static pw.Widget section(String title, List<pw.Widget> rows) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: 10),
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      ...rows,
    ],
  );

  static pw.Widget row(String label, String value, {bool bold = false}) {
    final style = bold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
        : null;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
