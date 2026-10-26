import '../../../core/l10n/l10n.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/monthly_pass.dart';

/// WhatsApp reminder for an expiring/active monthly pass.
String monthlyPassWhatsappMessage({
  required AppLocalizations l10n,
  required String plate,
  required MonthlyPass monthlyPass,
}) => l10n.monthlyPassWhatsappMessage(
  plate,
  Formatters.date(monthlyPass.endDate),
);
