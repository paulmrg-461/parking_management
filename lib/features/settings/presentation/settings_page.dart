import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/submission_listener.dart';
import '../application/branding_cubit.dart';
import '../application/settings_cubit.dart';
import '../domain/entities/parking_settings.dart';

final _websitePattern = RegExp(
  r'^(https?://)?[\w-]+(\.[\w-]+)+(:\d+)?(/.*)?$',
  caseSensitive: false,
);

/// Admin-only form for the singleton parking identity plus logo upload.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.pickLogo});

  /// Test seam: returns the picked logo bytes (or null when cancelled).
  final Future<Uint8List?> Function()? pickLogo;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _schedule;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _whatsapp;
  late final TextEditingController _evidenceRetention;
  late final TextEditingController _carCapacity;
  late final TextEditingController _motoCapacity;
  late final TextEditingController _keyCapacity;
  var _seeded = false;
  bool _whatsappAuto = false;
  List<String>? _baseline;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _address = TextEditingController();
    _schedule = TextEditingController();
    _phone = TextEditingController();
    _website = TextEditingController();
    _whatsapp = TextEditingController();
    _evidenceRetention = TextEditingController();
    _carCapacity = TextEditingController();
    _motoCapacity = TextEditingController();
    _keyCapacity = TextEditingController();
    unawaited(context.read<SettingsCubit>().load());
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _schedule.dispose();
    _phone.dispose();
    _website.dispose();
    _whatsapp.dispose();
    _evidenceRetention.dispose();
    _carCapacity.dispose();
    _motoCapacity.dispose();
    _keyCapacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return SubmissionListener<SettingsCubit, SettingsState>(
      submissionOf: (state) => state is SettingsLoaded ? state.submission : null,
      onSuccess: _onSaved,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            unawaited(_confirmLeave(context));
          }
        },
        child: ListPageScaffold(
          title: context.l10n.settingsTitle,
          onRefresh: cubit.load,
          body: BlocConsumer<SettingsCubit, SettingsState>(
          listenWhen: (previous, current) =>
              current is SettingsLoaded && previous is! SettingsLoaded,
          listener: (context, state) =>
              _seed((state as SettingsLoaded).settings),
          builder: (context, state) => switch (state) {
            SettingsInitial() || SettingsLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            SettingsFailure(:final message, :final failure) => Center(
              child: Text(
                context.l10n.errorText(message, failure),
                textAlign: TextAlign.center,
              ),
            ),
              SettingsLoaded() => _form(context, state.settings),
            },
          ),
        ),
      ),
    );
  }

  /// Every editable field, so "unsaved changes" needs no per-field listener.
  List<String> _snapshot() => [
    _name.text,
    _address.text,
    _schedule.text,
    _phone.text,
    _website.text,
    _whatsapp.text,
    _evidenceRetention.text,
    _carCapacity.text,
    _motoCapacity.text,
    _keyCapacity.text,
    '$_whatsappAuto',
  ];

  bool get _dirty => _baseline != null && !listEquals(_snapshot(), _baseline!);

  /// Settings are a form; leaving by accident should not drop the edits.
  Future<void> _confirmLeave(BuildContext context) async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: context.l10n.settingsDiscardTitle,
        body: context.l10n.settingsDiscardBody,
        confirmLabel: context.l10n.settingsDiscard,
        destructive: true,
      ),
    );
    if (discard && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _seed(ParkingSettings settings) {
    if (_seeded) {
      return;
    }
    _seeded = true;
    _name.text = settings.name;
    _address.text = settings.address;
    _schedule.text = settings.schedule;
    _phone.text = settings.phone;
    _website.text = settings.website;
    _whatsapp.text = settings.whatsapp;
    _evidenceRetention.text = settings.evidenceRetentionDays.toString();
    _carCapacity.text = settings.carCapacity.toString();
    _motoCapacity.text = settings.motoCapacity.toString();
    _keyCapacity.text = settings.keyCapacity.toString();
    _whatsappAuto = settings.whatsappAuto;
    _baseline = _snapshot();
  }

  void _onSaved(BuildContext context, Object? result) {
    _baseline = _snapshot();
    showInfoSnack(context, context.l10n.settingsSaved);
    unawaited(context.read<BrandingCubit>().load());
  }

  Widget _form(BuildContext context, ParkingSettings settings) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          _logoSection(context),
          const SizedBox(height: Space.md),
          TextFormField(
            key: const Key('settings_name'),
            controller: _name,
            maxLength: 80,
            decoration: InputDecoration(labelText: l10n.settingsName),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? l10n.fieldRequired
                : null,
          ),
          TextFormField(
            key: const Key('settings_address'),
            controller: _address,
            maxLength: 160,
            decoration: InputDecoration(labelText: l10n.settingsAddress),
          ),
          TextFormField(
            key: const Key('settings_schedule'),
            controller: _schedule,
            maxLength: 120,
            decoration: InputDecoration(labelText: l10n.settingsSchedule),
          ),
          TextFormField(
            key: const Key('settings_phone'),
            controller: _phone,
            maxLength: 32,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.settingsPhone),
          ),
          TextFormField(
            key: const Key('settings_website'),
            controller: _website,
            maxLength: 200,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: l10n.settingsWebsite),
            validator: (value) {
              final text = value?.trim() ?? '';
              return text.isNotEmpty && !_websitePattern.hasMatch(text)
                  ? l10n.settingsWebsiteInvalid
                  : null;
            },
          ),
          TextFormField(
            key: const Key('settings_whatsapp'),
            controller: _whatsapp,
            maxLength: 32,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.settingsWhatsapp),
          ),
          TextFormField(
            key: const Key('settings_evidence_retention'),
            controller: _evidenceRetention,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.settingsEvidenceRetention,
              helperText: l10n.settingsEvidenceRetentionHint,
            ),
            validator: (value) {
              final days = int.tryParse((value ?? '').trim());
              return days == null || days < 0 || days > 3650
                  ? l10n.invalidAmount
                  : null;
            },
          ),
          TextFormField(
            key: const Key('settings_car_capacity'),
            controller: _carCapacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.settingsCarCapacity,
              helperText: l10n.settingsCapacityHint,
            ),
            validator: _capacity,
          ),
          TextFormField(
            key: const Key('settings_moto_capacity'),
            controller: _motoCapacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.settingsMotoCapacity,
              helperText: l10n.settingsCapacityHint,
            ),
            validator: _capacity,
          ),
          TextFormField(
            key: const Key('settings_key_capacity'),
            controller: _keyCapacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.settingsKeyCapacity,
              helperText: l10n.settingsCapacityHint,
            ),
            validator: _capacity,
          ),
          SwitchListTile(
            key: const Key('settings_whatsapp_auto'),
            contentPadding: EdgeInsets.zero,
            value: _whatsappAuto,
            onChanged: (value) => setState(() => _whatsappAuto = value),
            title: Text(l10n.settingsWhatsappAuto),
            subtitle: Text(l10n.settingsWhatsappAutoHint),
          ),
          const SizedBox(height: Space.md),
          FilledButton(
            onPressed: () => _save(context, settings),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
  }

  Widget _logoSection(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<BrandingCubit, BrandingState>(
      builder: (context, branding) {
        final bytes = branding.logoOrNull;
        return Row(
          children: [
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(Space.xs),
                child: Image.memory(
                  bytes,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, size: 64),
                ),
              )
            else
              const Icon(Icons.local_parking_rounded, size: 64),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                l10n.settingsLogoSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton.tonal(
              onPressed: _uploadLogo,
              child: Text(l10n.settingsLogoPick),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save(BuildContext context, ParkingSettings current) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await context.read<SettingsCubit>().save(
      current.copyWith(
        name: _name.text.trim(),
        address: _address.text.trim(),
        schedule: _schedule.text.trim(),
        phone: _phone.text.trim(),
        website: _website.text.trim(),
        whatsapp: _whatsapp.text.trim(),
        evidenceRetentionDays:
            int.tryParse(_evidenceRetention.text.trim()) ?? 0,
        whatsappAuto: _whatsappAuto,
        carCapacity: int.tryParse(_carCapacity.text.trim()) ?? 0,
        motoCapacity: int.tryParse(_motoCapacity.text.trim()) ?? 0,
        keyCapacity: int.tryParse(_keyCapacity.text.trim()) ?? 0,
      ),
    );
  }

  String? _capacity(String? value) {
    final spaces = int.tryParse((value ?? '0').trim());
    return spaces == null || spaces < 0 || spaces > 10000
        ? context.l10n.invalidAmount
        : null;
  }

  Future<void> _uploadLogo() async {
    final pick = widget.pickLogo ?? _pickFromGallery;
    final bytes = await pick();
    if (bytes == null || !mounted) {
      return;
    }
    await context.read<SettingsCubit>().uploadLogo(bytes);
    if (!mounted) {
      return;
    }
    // Refreshes the preview only when the upload reached the backend.
    unawaited(context.read<BrandingCubit>().load());
  }

  static Future<Uint8List?> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
    );
    return file == null ? null : await file.readAsBytes();
  }
}
