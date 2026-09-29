import 'dart:convert';

import '../../../core/receipt/receipt_data.dart';
import '../../../core/utils/cop_formatter.dart';

/// Builds raw ESC/POS bytes for an 80mm thermal receipt. Pure Dart (no I/O),
/// so it can be unit-tested; the Bluetooth adapter sends the bytes to the
/// printer. Labels are ASCII-only Spanish so they survive the CP437 code page.
class EscPosGenerator {
  const EscPosGenerator();

  static const _init = [0x1B, 0x40]; // ESC @
  static const _cut = [0x1D, 0x56, 0x42, 0x00]; // GS V 66 0 (full cut)

  List<int> build(ReceiptData data) {
    final bytes = <int>[];

    bytes.addAll(_init);
    _text(bytes, 'PARQUEADERO', align: 1, bold: true, doubleSize: true);
    _text(
      bytes,
      data.isCheckOut ? 'RECIBO DE SALIDA' : 'RECIBO DE ENTRADA',
      align: 1,
    );
    _text(bytes, data.plate, align: 1, bold: true, doubleSize: true);
    _rule(bytes);

    _row(bytes, 'Placa', data.plate);
    _row(bytes, 'Entrada', _dateTime(data.entryTime));
    if (data.isCheckOut && data.exitTime != null) {
      _row(bytes, 'Salida', _dateTime(data.exitTime!));
      _row(bytes, 'Tiempo', _duration(data.exitTime!.difference(data.entryTime)));
    } else if (data.photoCount != null) {
      _row(bytes, 'Fotos', '${data.photoCount}');
    }

    if (data.pendingSync) {
      _text(bytes, 'PENDIENTE DE SINCRONIZAR', align: 1, bold: true);
    } else if (data.isCheckOut && data.amountCharged != null) {
      _rule(bytes);
      _row(bytes, 'Total', CopFormatter.format(data.amountCharged!), bold: true);
    }

    if (data.isCheckOut && !data.pendingSync && data.ticketNumber != null) {
      _row(bytes, 'Ticket', data.ticketNumber!);
    }

    _rule(bytes);
    _text(bytes, 'Generado el ${_dateTime(DateTime.now())}', align: 1);
    _text(bytes, 'Gracias por su visita', align: 1);
    _feed(bytes, 2);
    bytes.addAll(_cut);

    return bytes;
  }

  void _text(
    List<int> out,
    String text, {
    int align = 0,
    bool bold = false,
    bool doubleSize = false,
  }) {
    if (doubleSize) {
      out.addAll(const [0x1D, 0x21, 0x11]); // GS ! — double width + height
    }
    out.addAll([0x1B, 0x45, bold ? 1 : 0]); // ESC E — bold
    out.addAll([0x1B, 0x61, align]); // ESC a — alignment
    out.addAll(latin1.encode(text));
    out.add(0x0A);
    if (doubleSize) {
      out.addAll(const [0x1D, 0x21, 0x00]); // reset size
    }
    out.addAll(const [0x1B, 0x45, 0]); // reset bold
  }

  void _row(List<int> out, String label, String value, {bool bold = false}) {
    if (bold) {
      out.addAll(const [0x1B, 0x45, 1]);
    }
    out.addAll(latin1.encode('$label: $value'));
    out.add(0x0A);
    if (bold) {
      out.addAll(const [0x1B, 0x45, 0]);
    }
  }

  void _rule(List<int> out) {
    out.addAll(latin1.encode('--------------------------------'));
    out.add(0x0A);
  }

  void _feed(List<int> out, int n) {
    for (var i = 0; i < n; i++) {
      out.add(0x0A);
    }
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
