import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/l10n.dart';
import 'package:parking_management/core/utils/elapsed.dart';

void main() {
  test('Success: elapsed time is formatted in hours and minutes', () async {
    final l10n = await AppLocalizations.delegate.load(defaultLocale);
    final now = DateTime(2026, 10, 26, 12);

    expect(
      elapsedLabel(l10n, DateTime(2026, 10, 26, 9, 30), now: now),
      '2 h 30 min',
    );
    expect(
      elapsedLabel(l10n, DateTime(2026, 10, 26, 11, 45), now: now),
      '15 min',
    );
  });

  test('Security: a clock behind the server never shows negative time', () async {
    final l10n = await AppLocalizations.delegate.load(defaultLocale);

    expect(
      elapsedLabel(
        l10n,
        DateTime(2026, 10, 26, 13),
        now: DateTime(2026, 10, 26, 12),
      ),
      '0 min',
    );
  });

  test('Success: 24 hours marks a long stay', () {
    final now = DateTime(2026, 10, 26, 12);

    expect(isLongStay(DateTime(2026, 10, 25, 12), now: now), isTrue);
    expect(isLongStay(DateTime(2026, 10, 25, 13), now: now), isFalse);
  });
}
