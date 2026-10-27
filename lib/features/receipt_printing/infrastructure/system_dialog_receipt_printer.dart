import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/receipt/receipt_data.dart';
import '../../../core/receipt/receipt_labels.dart';
import '../../../core/utils/cop_formatter.dart';
import '../../settings/domain/entities/parking_settings.dart';
import '../../settings/domain/repositories/parking_settings_repository.dart';
import '../domain/repositories/receipt_printer.dart';

/// Prints a receipt through the OS print/share dialog by rendering it to a
/// PDF (works on Android and web). The operator can then pick a system
/// printer or save the PDF. Identity comes from the cached settings so an
/// offline print still renders the configured brand (or `PARQUEADERO`).
class SystemDialogReceiptPrinter implements ReceiptPrinter {
  SystemDialogReceiptPrinter(this._settings);

  final ParkingSettingsRepository _settings;

  @override
  Future<void> printPdf(ReceiptData data, ReceiptLabels labels) async {
    final settings = await _cachedSettings();
    final logo = await _cachedLogo(settings);
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(8),
        build: (context) => _build(context, data, settings, logo, labels),
      ),
    );
    await Printing.layoutPdf(
      name: 'recibo-${data.plate}',
      onLayout: (format) async => document.save(),
    );
  }

  Future<ParkingSettings?> _cachedSettings() async {
    try {
      return await _settings.loadCached();
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _cachedLogo(ParkingSettings? settings) async {
    if (settings == null || settings.logoVersion == 0) {
      return null;
    }
    try {
      return await _settings.loadLogo(settings.logoVersion);
    } catch (_) {
      return null;
    }
  }

  pw.Widget _build(
    pw.Context context,
    ReceiptData data,
    ParkingSettings? settings,
    Uint8List? logo,
    ReceiptLabels labels,
  ) {
    const bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _title(logo, settings),
        pw.Text(
          data.isCheckOut ? labels.checkOutTitle : labels.checkInTitle,
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text(data.plate, textAlign: pw.TextAlign.center, style: bold),
        pw.SizedBox(height: 8),
        pw.Divider(),
        _row(context, labels.plate, data.plate),
        _row(context, labels.entry, _dateTime(data.entryTime)),
        if (data.isCheckOut && data.exitTime != null) ...[
          _row(context, labels.exit, _dateTime(data.exitTime!)),
          _row(
            context,
            labels.duration,
            _duration(data.exitTime!.difference(data.entryTime)),
          ),
        ] else if (data.photoCount != null)
          _row(context, labels.photos, '${data.photoCount}'),
        if (data.pendingSync)
          pw.Text(labels.pendingSync, textAlign: pw.TextAlign.center)
        else if (data.isCheckOut && data.amountCharged != null) ...[
          pw.Divider(),
          _row(
            context,
            labels.total,
            CopFormatter.format(data.amountCharged!),
            bold: true,
          ),
        ],
        if (data.isCheckOut && !data.pendingSync && data.discountAmount > 0)
          _row(
            context,
            labels.discount,
            '-${CopFormatter.format(data.discountAmount)}',
          ),
        if (data.isCheckOut && !data.pendingSync && data.paymentMethod != null)
          _row(context, labels.payment, labels.paymentMethod(data.paymentMethod!)),
        if (data.isCheckOut && !data.pendingSync && data.ticketNumber != null)
          _row(context, labels.ticket, data.ticketNumber!),
        pw.Divider(),
        if (!data.isCheckOut) ...[
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: Barcode.qrCode(),
              data: data.plate,
              width: 84,
              height: 84,
            ),
          ),
          pw.Text(
            labels.scanHint,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Text(
          '${labels.generatedOn} ${_dateTime(DateTime.now())}',
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(labels.thanks, textAlign: pw.TextAlign.center),
        ..._footer(settings),
      ],
    );
  }

  pw.Widget _title(Uint8List? logo, ParkingSettings? settings) {
    const bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    return pw.Column(
      children: [
        if (logo != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.SizedBox(
              width: 48,
              height: 48,
              child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
            ),
          ),
        pw.Text(_header(settings), textAlign: pw.TextAlign.center, style: bold),
      ],
    );
  }

  String _header(ParkingSettings? settings) {
    final name = settings?.name.trim() ?? '';
    return name.isEmpty ? 'PARQUEADERO' : name;
  }

  List<pw.Widget> _footer(ParkingSettings? settings) {
    if (settings == null) {
      return const [];
    }
    final lines = [settings.address, settings.schedule, settings.phone]
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    return [
      for (final line in lines)
        pw.Text(line, textAlign: pw.TextAlign.center),
    ];
  }

  pw.Widget _row(pw.Context context, String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: bold ? const pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
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
