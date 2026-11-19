import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/l10n/l10n.dart';
import 'package:parking_management/core/money/currency.dart';
import 'package:parking_management/core/money/money.dart';
import 'package:parking_management/core/sync/conflict/entity_fields.dart';
import 'package:parking_management/core/sync/pending_mutation.dart';

/// The conflict granularity of each entity (design §5). A payload key without
/// a spec would render as an unlabeled row, so this test fails loudly instead.
const _catalog = {
  MutationEntity.vehicle: {
    'category_id',
    'color',
    'brand',
    'owner_phone',
    'owner_name',
  },
  MutationEntity.tariff: {'type', 'amount', 'start_time', 'end_time', 'active'},
  MutationEntity.category: {'name', 'capacity'},
  MutationEntity.settings: {
    'name',
    'address',
    'schedule',
    'phone',
    'website',
    'whatsapp',
    'evidence_retention_days',
    'reservation_grace_minutes',
    'whatsapp_auto',
    'car_capacity',
    'moto_capacity',
    'key_capacity',
    'car_out_of_service',
    'moto_out_of_service',
    'legal_policy',
    'currency',
    'min_app_version',
    'police_phone',
  },
  MutationEntity.checkIn: <String>{},
  MutationEntity.checkOut: <String>{},
};

void main() {
  test('Success: every conflictable key of every entity has a spec', () {
    for (final entry in _catalog.entries) {
      final keys = fieldsFor(entry.key).map((spec) => spec.key).toSet();
      expect(
        keys,
        entry.value,
        reason: 'catalog mismatch for ${entry.key.name}',
      );
    }
  });

  test('Success: every spec has a non-empty label in both languages', () async {
    for (final locale in const [Locale('es'), Locale('en')]) {
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final entity in _catalog.keys) {
        for (final spec in fieldsFor(entity)) {
          expect(
            spec.label(l10n).trim(),
            isNotEmpty,
            reason:
                '${entity.name}.${spec.key} has no ${locale.languageCode} '
                'label',
          );
        }
      }
    }
  });

  test('Success: amount renders with Money in the site currency', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    final spec = fieldFor(MutationEntity.tariff, 'amount')!;

    Money.configure(Currency.cop);
    expect(spec.formatWith(l10n, 5000), r'$5.000');

    Money.configure(Currency.usd);
    expect(spec.formatWith(l10n, 5000), r'US$50.00');

    Money.configure(Currency.cop);
  });

  test('Success: null renders as an empty marker, not the word null', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('es'));

    expect(formatValue(l10n, null), '—');
    expect(formatValue(l10n, ''), '—');
    expect(formatValue(l10n, true), 'Sí');
    expect(formatValue(l10n, false), 'No');
    expect(formatValue(l10n, 12), '12');
  });

  test('Success: a tariff start time is shown as HH:mm', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('es'));
    final spec = fieldFor(MutationEntity.tariff, 'start_time')!;

    expect(spec.formatWith(l10n, '18:00:00'), '18:00');
  });

  test('Security: an unknown key resolves to nothing instead of guessing', () {
    expect(fieldFor(MutationEntity.vehicle, 'version'), isNull);
    expect(fieldFor(MutationEntity.checkOut, 'color'), isNull);
  });
}
