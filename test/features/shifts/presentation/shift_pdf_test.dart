import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/l10n.dart';
import 'package:parking_management/features/shifts/presentation/shift_pdf.dart';

import '../../../helpers/fake_shift_repository.dart';

void main() {
  test('Success: the reconciliation PDF is a valid PDF document', () async {
    final bytes = await buildShiftPdf(
      l10n: await AppLocalizations.delegate.load(defaultLocale),
      shift: sampleShift(closed: true, countedCash: 14000),
      lotName: 'Central',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
