import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:printing/printing.dart';

import '../l10n/l10n.dart';
import '../widgets/submission_feedback.dart';

/// Opens the OS share/print sheet for [bytes]. A platform without a share
/// target keeps the app usable: the failure is a snack, never a crash.
Future<void> sharePdfBytes(
  BuildContext context, {
  required Uint8List bytes,
  required String filename,
}) async {
  try {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  } catch (_) {
    if (context.mounted) {
      showErrorSnack(context, context.l10n.errorUnknown);
    }
  }
}

/// `reporte-2026-01-01-2026-01-31.pdf` style name.
String pdfFileName(String prefix, DateTime start, [DateTime? end]) {
  String date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
  return end == null
      ? '$prefix-${date(start)}.pdf'
      : '$prefix-${date(start)}-${date(end)}.pdf';
}
