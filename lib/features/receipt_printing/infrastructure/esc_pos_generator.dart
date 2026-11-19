import 'dart:convert';

import '../../../core/fare/fare_adjustment.dart';
import '../../../core/receipt/receipt_data.dart';
import '../../../core/receipt/receipt_labels.dart';
import '../../../core/utils/cop_formatter.dart';
import '../../settings/domain/entities/parking_settings.dart';

/// Builds raw ESC/POS bytes for an 80mm thermal receipt. Pure Dart (no I/O),
/// so it can be unit-tested; the Bluetooth adapter sends the bytes to the
/// printer. Labels are ASCII-only Spanish so they survive the CP437 code page.
class EscPosGenerator {
  const EscPosGenerator();

  static const _init = [0x1B, 0x40]; // ESC @
  static const _cut = [0x1D, 0x56, 0x42, 0x00]; // GS V 66 0 (full cut)

  /// [settings] is null when nothing was ever cached: the header then falls
  /// back to `PARQUEADERO` so printing never fails.
  /// ESC/POS QR (GS ( k, model 2). Cheap 80 mm printers support it; the plate
  /// is ASCII so the code page does not matter.
  void _qr(List<int> bytes, String text) {
    final payload = utf8.encode(text);
    final length = payload.length + 3;
    bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]);
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
    bytes.addAll([
      0x1D,
      0x28,
      0x6B,
      length & 0xFF,
      (length >> 8) & 0xFF,
      0x31,
      0x50,
      0x30,
      ...payload,
    ]);
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
    bytes.addAll([0x0A, 0x0A]);
  }

  List<int> build(
    ReceiptData data,
    ParkingSettings? settings, [
    ReceiptLabels labels = ReceiptLabels.spanish,
  ]) {
    final bytes = <int>[];

    bytes.addAll(_init);
    _text(bytes, _header(settings), align: 1, bold: true, doubleSize: true);
    _text(
      bytes,
      data.isCheckOut ? labels.checkOutTitle : labels.checkInTitle,
      align: 1,
    );
    _text(bytes, data.plate, align: 1, bold: true, doubleSize: true);
    _rule(bytes);

    _row(bytes, labels.plate, data.plate);
    _row(bytes, labels.entry, _dateTime(data.entryTime));
    if (data.isCheckOut && data.exitTime != null) {
      _row(bytes, labels.exit, _dateTime(data.exitTime!));
      _row(
        bytes,
        labels.duration,
        _duration(data.exitTime!.difference(data.entryTime)),
      );
    } else if (data.photoCount != null) {
      _row(bytes, labels.photos, '${data.photoCount}');
    }

    if (data.isCheckOut && !data.pendingSync && data.pricingLabel != null) {
      _row(bytes, labels.pricingRule, data.pricingLabel!);
    }
    if (!data.pendingSync && data.loyaltyRequired != null) {
      _row(
        bytes,
        '',
        data.loyaltyRewardEarned
            ? labels.loyaltyRewardEarned
            : labels.loyaltyVisit(
                (data.loyaltyVisits ?? 0) + 1,
                data.loyaltyRequired!,
              ),
      );
    }
    if (data.isCheckOut && !data.pendingSync && data.grossAmount != null) {
      _row(bytes, labels.gross, CopFormatter.format(data.grossAmount!));
      for (final line in data.adjustments) {
        _row(
          bytes,
          line.type == FareAdjustmentType.reward
              ? labels.loyaltyReward
              : '${labels.benefit} ${line.label}',
          '-${CopFormatter.format(line.amount)}',
        );
      }
    }

    if (data.pendingSync) {
      _text(bytes, labels.pendingSync, align: 1, bold: true);
    } else if (data.isCheckOut && data.amountCharged != null) {
      _rule(bytes);
      _row(
        bytes,
        labels.total,
        CopFormatter.format(data.amountCharged!),
        bold: true,
      );
    }

    if (data.isCheckOut && !data.pendingSync && data.discountAmount > 0) {
      _row(
        bytes,
        labels.discount,
        '-${CopFormatter.format(data.discountAmount)}',
      );
    }

    if (data.isCheckOut && !data.pendingSync && data.paymentMethod != null) {
      _row(
        bytes,
        labels.payment,
        labels.paymentMethod(data.paymentMethod!, data.cardType),
      );
    }

    if (data.isCheckOut && !data.pendingSync && data.onlinePaidAmount > 0) {
      _row(bytes, labels.onlinePaid, CopFormatter.format(data.onlinePaidAmount));
    }
    if (data.isCheckOut && !data.pendingSync && data.cashReceived != null) {
      _row(bytes, labels.received, CopFormatter.format(data.cashReceived!));
    }
    if (data.isCheckOut && !data.pendingSync && data.cashChange != null) {
      _row(bytes, labels.change, CopFormatter.format(data.cashChange!));
    }

    if (data.isCheckOut && !data.pendingSync && data.ticketNumber != null) {
      _row(bytes, labels.ticket, data.ticketNumber!);
    }

    if (data.isCheckOut &&
        (data.fiscalNumber != null || data.fiscalPending)) {
      _rule(bytes);
      _text(
        bytes,
        data.fiscalType == 'invoice'
            ? labels.fiscalInvoice
            : labels.fiscalPos,
        align: 1,
      );
      if (data.fiscalNumber != null) {
        _row(bytes, labels.ticket, data.fiscalNumber!);
      }
      if (data.cufe != null) {
        _text(bytes, '${labels.cufeLabel} ${data.cufe}', align: 1);
      }
      if (data.fiscalPending) {
        _text(bytes, labels.fiscalPendingLabel, align: 1);
      }
      if (data.fiscalQr != null) {
        _qr(bytes, data.fiscalQr!);
      }
    }

    if (!data.isCheckOut) {
      _qr(bytes, data.plate);
      _text(bytes, labels.scanHint, align: 1);
    }
    if (data.evidenceUrl != null) {
      _rule(bytes);
      _qr(bytes, data.evidenceUrl!);
      _text(bytes, labels.evidenceHint, align: 1);
    }
    if (data.feedbackUrl != null) {
      _rule(bytes);
      _qr(bytes, data.feedbackUrl!);
      _text(bytes, labels.feedbackHint, align: 1);
    }
    if (!data.isCheckOut ||
        data.evidenceUrl != null ||
        data.feedbackUrl != null) {
      _rule(bytes);
    }

    _text(
      bytes,
      '${labels.generatedOn} ${_dateTime(DateTime.now())}',
      align: 1,
    );
    _text(bytes, labels.thanks, align: 1);
    _footer(bytes, settings);
    _feed(bytes, 2);
    bytes.addAll(_cut);

    return bytes;
  }

  String _header(ParkingSettings? settings) {
    final name = settings?.name.trim() ?? '';
    return name.isEmpty ? 'PARQUEADERO' : name;
  }

  void _footer(List<int> out, ParkingSettings? settings) {
    if (settings == null) {
      return;
    }
    final lines = [
      settings.address,
      settings.schedule,
      settings.phone,
    ].map((line) => line.trim()).where((line) => line.isNotEmpty);
    for (final line in lines) {
      _text(out, line, align: 1);
    }
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
    out.addAll(latin1.encode(_latin1Safe(text)));
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
    out.addAll(latin1.encode(_latin1Safe('$label: $value')));
    out.add(0x0A);
    if (bold) {
      out.addAll(const [0x1B, 0x45, 0]);
    }
  }

  /// Replaces anything outside CP437/Latin-1 so user-typed settings (emoji,
  /// accents) can never throw mid-print.
  String _latin1Safe(String text) =>
      String.fromCharCodes(text.runes.map((r) => r < 0x100 ? r : 0x3F));

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
