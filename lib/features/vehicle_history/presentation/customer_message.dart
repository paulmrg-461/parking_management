import '../../../core/l10n/l10n.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/vehicle_history.dart';

/// WhatsApp receipt for one closed session: the same numbers the printed
/// receipt shows, prefilled in the chat.
String receiptWhatsappMessage({
  required AppLocalizations l10n,
  required String plate,
  required VehicleHistorySession session,
}) {
  final lines = <String>[
    l10n.vehicleWhatsappReceipt(plate),
    '${l10n.receiptEntry}: ${Formatters.dateTimeFull(session.entryTime)}',
  ];
  if (session.exitTime != null) {
    lines.add(
      '${l10n.receiptExit}: ${Formatters.dateTimeFull(session.exitTime!)}',
    );
  }
  if (session.amountCharged != null) {
    lines.add(
      '${l10n.receiptAmount}: ${Formatters.money(session.amountCharged!)}',
    );
  }
  if (session.discountAmount > 0) {
    lines.add(
      '${l10n.receiptDiscount}: -${Formatters.money(session.discountAmount)}',
    );
  }
  if (session.ticketNumber != null) {
    lines.add('${l10n.receiptTicket}: ${session.ticketNumber}');
  }
  lines.add(l10n.vehicleWhatsappThanks);
  return lines.join('\n');
}

/// Short greeting used from the customer's card (no specific session).
String generalWhatsappMessage({
  required AppLocalizations l10n,
  required String plate,
}) => l10n.vehicleWhatsappHello(plate);
