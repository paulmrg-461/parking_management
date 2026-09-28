import 'package:bluetooth_print/bluetooth_print_model.dart';

import '../../../core/receipt/receipt_data.dart';
import '../../../core/utils/cop_formatter.dart';

/// Builds the ESC/POS text lines for an 80mm thermal receipt, consumed by
/// `bluetooth_print`. Pure (no I/O) so it can be unit-tested.
class ReceiptLineBuilder {
  const ReceiptLineBuilder();

  List<LineText> build(ReceiptData data) {
    final lines = <LineText>[];

    lines.add(
      LineText(
        type: LineText.TYPE_TEXT,
        content: 'PARQUEADERO',
        weight: 1,
        align: LineText.ALIGN_CENTER,
        fontZoom: 2,
        linefeed: 1,
      ),
    );
    lines.add(
      LineText(
        type: LineText.TYPE_TEXT,
        content: data.isCheckOut ? 'RECIBO DE SALIDA' : 'RECIBO DE ENTRADA',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ),
    );
    lines.add(
      LineText(
        type: LineText.TYPE_TEXT,
        content: data.plate,
        weight: 1,
        align: LineText.ALIGN_CENTER,
        fontZoom: 2,
        linefeed: 1,
      ),
    );
    lines.add(_rule());

    lines.add(_row('Placa', data.plate));
    lines.add(_row('Entrada', _dateTime(data.entryTime)));
    if (data.isCheckOut && data.exitTime != null) {
      lines.add(_row('Salida', _dateTime(data.exitTime!)));
      lines.add(
        _row(
          'Tiempo',
          _duration(data.exitTime!.difference(data.entryTime)),
        ),
      );
    } else if (data.photoCount != null) {
      lines.add(_row('Fotos', '${data.photoCount}'));
    }

    if (data.pendingSync) {
      lines.add(
        LineText(
          type: LineText.TYPE_TEXT,
          content: 'PENDIENTE DE SINCRONIZAR',
          weight: 1,
          align: LineText.ALIGN_CENTER,
          linefeed: 1,
        ),
      );
    } else if (data.isCheckOut && data.amountCharged != null) {
      lines.add(_rule());
      lines.add(
        _row('Total', CopFormatter.format(data.amountCharged!), bold: true),
      );
    }

    if (data.isCheckOut && !data.pendingSync && data.ticketNumber != null) {
      lines.add(_row('Ticket', data.ticketNumber!));
    }

    lines.add(_rule());
    lines.add(
      LineText(
        type: LineText.TYPE_TEXT,
        content: 'Generado el ${_dateTime(DateTime.now())}',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ),
    );
    lines.add(
      LineText(
        type: LineText.TYPE_TEXT,
        content: 'Gracias por su visita',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ),
    );

    return lines;
  }

  LineText _rule() => LineText(
    type: LineText.TYPE_TEXT,
    content: '--------------------------------',
    align: LineText.ALIGN_CENTER,
    linefeed: 1,
  );

  LineText _row(String label, String value, {bool bold = false}) => LineText(
    type: LineText.TYPE_TEXT,
    content: '$label: $value',
    weight: bold ? 1 : 0,
    align: LineText.ALIGN_LEFT,
    linefeed: 1,
  );

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
