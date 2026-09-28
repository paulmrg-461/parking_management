import '../../../core/l10n/l10n.dart';
import '../domain/entities/tariff.dart';

extension TariffTypeLabel on TariffType {
  String label(AppLocalizations l10n) => switch (this) {
    TariffType.hourly => l10n.tariffTypeHourly,
    TariffType.daily => l10n.tariffTypeDaily,
    TariffType.nightly => l10n.tariffTypeNightly,
    TariffType.monthly => l10n.tariffTypeMonthly,
  };
}
