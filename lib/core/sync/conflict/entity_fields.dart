import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../pending_mutation.dart';

/// How one conflicting field is labelled and rendered in the resolution dialog.
class FieldSpec {
  const FieldSpec({required this.key, required this.label, this.format});

  final String key;
  final String Function(AppLocalizations l10n) label;

  /// Renders a raw row value; defaults to [formatValue].
  final String Function(AppLocalizations l10n, Object? value)? format;

  String formatWith(AppLocalizations l10n, Object? value) =>
      (format ?? formatValue)(l10n, value);
}

/// `true`/`false` as the site language renders them, numbers verbatim, empty
/// text as an em dash so two "empty" values never look different.
String formatValue(AppLocalizations l10n, Object? value) {
  if (value == null) {
    return '—';
  }
  if (value is bool) {
    return value ? l10n.cfYes : l10n.cfNo;
  }
  if (value is num) {
    return '$value';
  }
  final text = '$value'.trim();
  return text.isEmpty ? '—' : text;
}

String _money(AppLocalizations l10n, Object? value) =>
    value is num ? Money.format(value.toInt()) : formatValue(l10n, value);

String _time(AppLocalizations l10n, Object? value) {
  final text = value == null ? '' : '$value'.trim();
  return text.isEmpty ? '—' : text.substring(0, text.length.clamp(0, 5));
}

String _id(AppLocalizations l10n, Object? value) =>
    value is num ? '#${value.toInt()}' : formatValue(l10n, value);

FieldSpec _text(String key, String Function(AppLocalizations l10n) label) =>
    FieldSpec(key: key, label: label);

FieldSpec _amount(String key, String Function(AppLocalizations l10n) label) =>
    FieldSpec(key: key, label: label, format: _money);

/// The fields a conflict can mention for [entity], with the label the operator
/// already knows from the edit form.
///
/// Money renders in the site currency through [Money]; times as `HH:mm`.
List<FieldSpec> fieldsFor(MutationEntity entity) => switch (entity) {
  MutationEntity.vehicle => [
    FieldSpec(
      key: 'category_id',
      label: (l10n) => l10n.fieldCategory,
      format: _id,
    ),
    _text('color', (l10n) => l10n.fieldColor),
    _text('brand', (l10n) => l10n.fieldBrand),
    _text('owner_name', (l10n) => l10n.vehicleOwnerNameOptional),
    _text('owner_phone', (l10n) => l10n.vehiclePhone),
  ],
  MutationEntity.tariff => [
    _text('type', (l10n) => l10n.fieldType),
    _amount('amount', (l10n) => l10n.fieldAmount),
    FieldSpec(
      key: 'start_time',
      label: (l10n) => l10n.tariffStart,
      format: _time,
    ),
    FieldSpec(key: 'end_time', label: (l10n) => l10n.tariffEnd, format: _time),
    _text('active', (l10n) => l10n.tariffActiveLabel),
  ],
  MutationEntity.category => [
    _text('name', (l10n) => l10n.fieldName),
    _text('capacity', (l10n) => l10n.categoryCapacityLabel),
  ],
  MutationEntity.settings => [
    _text('name', (l10n) => l10n.settingsName),
    _text('address', (l10n) => l10n.settingsAddress),
    _text('schedule', (l10n) => l10n.settingsSchedule),
    _text('phone', (l10n) => l10n.settingsPhone),
    _text('website', (l10n) => l10n.settingsWebsite),
    _text('whatsapp', (l10n) => l10n.settingsWhatsapp),
    _text('evidence_retention_days', (l10n) => l10n.settingsEvidenceRetention),
    _text('reservation_grace_minutes', (l10n) => l10n.settingsReservationGrace),
    _text('whatsapp_auto', (l10n) => l10n.settingsWhatsappAuto),
    _text('car_capacity', (l10n) => l10n.settingsCarCapacity),
    _text('moto_capacity', (l10n) => l10n.settingsMotoCapacity),
    _text('key_capacity', (l10n) => l10n.settingsKeyCapacity),
    _text('car_out_of_service', (l10n) => l10n.settingsCarOutOfService),
    _text('moto_out_of_service', (l10n) => l10n.settingsMotoOutOfService),
    _text('legal_policy', (l10n) => l10n.settingsLegalPolicy),
    _text('currency', (l10n) => l10n.settingsCurrency),
    _text('min_app_version', (l10n) => l10n.settingsMinVersion),
    _text('police_phone', (l10n) => l10n.settingsPolicePhone),
  ],
  // Check-in/check-out are safe by idempotency, never by version.
  MutationEntity.checkIn || MutationEntity.checkOut => const [],
};

/// The [FieldSpec] for [key] in [entity], `null` when the catalog is missing it
/// (which a test forbids for every known payload key).
FieldSpec? fieldFor(MutationEntity entity, String key) =>
    fieldsFor(entity).where((spec) => spec.key == key).firstOrNull;
