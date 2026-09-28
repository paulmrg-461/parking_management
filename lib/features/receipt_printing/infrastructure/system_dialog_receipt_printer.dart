import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/receipt/receipt_data.dart';
import '../../../core/utils/cop_formatter.dart';
import '../domain/repositories/receipt_printer.dart';

/// Prints a receipt through the OS print/share dialog by rendering it to a
/// PDF (works on Android and web). The operator can then pick a system
/// printer or save the PDF.
class SystemDialogReceiptPrinter implements ReceiptPrinter {
  const SystemDialogReceiptPrinter();

  @override
  Future<void> printPdf(ReceiptData data) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(8),
        build: (context) => _build(context, data),
      ),
    );
    await Printing.layoutPdf(
      name: 'recibo-${data.plate}',
      onLayout: (format) async => document.save(),
    );
  }

  pw.Widget _build(pw.Context context, ReceiptData data) {
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('PARQUEADERO', textAlign: pw.TextAlign.center, style: bold),
        pw.Text(
          data.isCheckOut ? 'RECIBO DE SALIDA' : 'RECIBO DE ENTRADA',
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text(data.plate, textAlign: pw.TextAlign.center, style: bold),
        pw.SizedBox(height: 8),
        pw.Divider(),
        _row(context, 'Placa', data.plate),
        _row(context, 'Entrada', _dateTime(data.entryTime)),
        if (data.isCheckOut && data.exitTime != null) ...[
          _row(context, 'Salida', _dateTime(data.exitTime!)),
          _row(context, 'Tiempo', _duration(data.exitTime!.difference(data.entryTime))),
        ] else if (data.photoCount != null)
          _row(context, 'Fotos', '${data.photoCount}'),
        if (data.pendingSync)
          pw.Text('PENDIENTE DE SINCRONIZAR', textAlign: pw.TextAlign.center)
        else if (data.isCheckOut && data.amountCharged != null) ...[
          pw.Divider(),
          _row(context, 'Total', CopFormatter.format(data.amountCharged!), bold: true),
        ],
        if (data.isCheckOut && !data.pendingSync && data.ticketNumber != null)
          _row(context, 'Ticket', data.ticketNumber!),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generado el ${_dateTime(DateTime.now())}',
          textAlign: pw.TextAlign.center,
        ),
        pw.Text('Gracias por su visita', textAlign: pw.TextAlign.center),
      ],
    );
  }

  pw.Widget _row(pw.Context context, String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
        ],
      ),
    );
  }

  String _dateTime(DateTime value) {
    final l = value.toLocal();
    return '${_two(l.day)}/${_two(l.month)}/${l.year} '
        '${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
  }

  String _duration(Duration value) {
    final minutes = value.isNegative ? 0 : value.inMinutes;
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
