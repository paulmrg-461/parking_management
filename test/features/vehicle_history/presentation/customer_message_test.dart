import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/l10n.dart';
import 'package:parking_management/features/vehicle_history/domain/entities/vehicle_history.dart';
import 'package:parking_management/features/vehicle_history/presentation/customer_message.dart';

VehicleHistorySession _session() => VehicleHistorySession(
  id: 1,
  entryTime: DateTime(2026, 10, 24, 8),
  exitTime: DateTime(2026, 10, 24, 10),
  status: 'closed',
  amountCharged: 7000,
  ticketNumber: 'TCK-DEF-000001',
  paymentMethod: 'cash',
  discountAmount: 1000,
);

void main() {
  test('Success: the receipt message carries the same numbers', () async {
    final l10n = await AppLocalizations.delegate.load(defaultLocale);

    final message = receiptWhatsappMessage(
      l10n: l10n,
      plate: 'ABC123',
      session: _session(),
    );

    expect(message, contains('ABC123'));
    expect(message, contains('Entrada'));
    expect(message, contains('Salida'));
    expect(message, contains('7.000'));
    expect(message, contains('1.000'));
    expect(message, contains('TCK-DEF-000001'));
    expect(message, contains('Gracias por tu visita'));
  });

  test('Security: an open session omits the exit and amount', () async {
    final l10n = await AppLocalizations.delegate.load(defaultLocale);

    final message = receiptWhatsappMessage(
      l10n: l10n,
      plate: 'ABC123',
      session: VehicleHistorySession(
        id: 1,
        entryTime: DateTime(2026, 10, 24, 8),
        status: 'open',
      ),
    );

    expect(message, isNot(contains('Salida')));
    expect(message, isNot(contains('Total cobrado')));
  });

  test('Success: the general greeting names the plate', () async {
    final l10n = await AppLocalizations.delegate.load(defaultLocale);

    expect(
      generalWhatsappMessage(l10n: l10n, plate: 'ABC123'),
      contains('ABC123'),
    );
  });
}
