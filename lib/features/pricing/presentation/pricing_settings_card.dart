import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/entities/pricing_settings.dart';

/// Switch + guard rails of the lot, with inline validation.
class PricingSettingsCard extends StatefulWidget {
  const PricingSettingsCard({
    super.key,
    required this.settings,
    required this.onSave,
  });

  final PricingSettings settings;
  final ValueChanged<PricingSettings> onSave;

  @override
  State<PricingSettingsCard> createState() => _PricingSettingsCardState();
}

class _PricingSettingsCardState extends State<PricingSettingsCard> {
  late final TextEditingController _floor = TextEditingController(
    text: '${widget.settings.floorBps ~/ 100}',
  );
  late final TextEditingController _ceiling = TextEditingController(
    text: '${widget.settings.ceilingBps ~/ 100}',
  );
  late final TextEditingController _round = TextEditingController(
    text: '${widget.settings.roundTo}',
  );
  late bool _enabled = widget.settings.enabled;
  String? _error;

  @override
  void dispose() {
    _floor.dispose();
    _ceiling.dispose();
    _round.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = context.l10n;
    final floor = int.tryParse(_floor.text.trim());
    final ceiling = int.tryParse(_ceiling.text.trim());
    final round = int.tryParse(_round.text.trim());
    if (floor == null || floor < 10 || floor > 100) {
      setState(() => _error = l10n.errorInvalidPricingSettings);
      return;
    }
    if (ceiling == null || ceiling < 100 || ceiling > 500) {
      setState(() => _error = l10n.errorInvalidPricingSettings);
      return;
    }
    if (round == null || round < 1 || round > 1000) {
      setState(() => _error = l10n.errorInvalidPricingSettings);
      return;
    }
    setState(() => _error = null);
    widget.onSave(
      PricingSettings(
        enabled: _enabled,
        floorBps: floor * 100,
        ceilingBps: ceiling * 100,
        roundTo: round,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const Key('pricing_settings_card'),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const Key('pricing_enabled'),
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              title: Text(l10n.pricingEnabled),
              subtitle: Text(l10n.pricingEnabledHint),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('pricing_floor'),
                    controller: _floor,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.pricingFloor),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: TextFormField(
                    key: const Key('pricing_ceiling'),
                    controller: _ceiling,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.pricingCeiling),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: TextFormField(
                    key: const Key('pricing_round'),
                    controller: _round,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.pricingRoundTo),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: Space.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('pricing_settings_save'),
                onPressed: _save,
                child: Text(l10n.actionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
