import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/l10n.dart';
import 'package:parking_management/features/monthly_passes/domain/entities/monthly_pass.dart';
import 'package:parking_management/features/monthly_passes/presentation/customer_message.dart';

void main() {
  test('Success: the reminder names the plate and the expiry date', () async {
    final l10n = await AppLocalizations.delegate.load(defaultLocale);

    final message = monthlyPassWhatsappMessage(
      l10n: l10n,
      plate: 'ABC123',
      monthlyPass: MonthlyPass(
        id: 1,
        vehicleId: 1,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        amount: 100000,
      ),
    );

    expect(message, contains('ABC123'));
    expect(message, contains('31/1/2026'));
  });
}
