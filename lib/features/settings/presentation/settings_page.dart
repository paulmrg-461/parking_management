import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/utils/policy_template.dart';
import '../../../core/widgets/submission_listener.dart';
import '../application/branding_cubit.dart';
import '../application/settings_cubit.dart';
import '../../check_out/domain/entities/slot_board.dart';
import '../../spots/domain/repositories/spot_repository.dart';
import '../domain/entities/parking_settings.dart';

final _websitePattern = RegExp(
  r'^(https?://)?[\w-]+(\.[\w-]+)+(:\d+)?(/.*)?$',
  caseSensitive: false,
);

/// Admin-only form for the singleton parking identity plus logo upload.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.pickLogo, this.spots});

  /// Optional map access: when the site already drew bays, out-of-service is
  /// per bay and the count fields are hidden.
  final SpotRepository? spots;

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
  late final TextEditingController _carOutOfService;
  late final TextEditingController _motoOutOfService;
  late final TextEditingController _legalPolicy;
  String _currency = 'COP';
  var _seeded = false;
  bool _whatsappAuto = false;
  List<String>? _baseline;
  int _carBays = 0;
  int _carBaysOut = 0;
  int _motoBays = 0;
  int _motoBaysOut = 0;

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
    _carOutOfService = TextEditingController();
    _motoOutOfService = TextEditingController();
    _legalPolicy = TextEditingController();
    unawaited(context.read<SettingsCubit>().load());
    unawaited(_loadSpotCounts());
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
    _carOutOfService.dispose();
    _motoOutOfService.dispose();
    _legalPolicy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return SubmissionListener<SettingsCubit, SettingsState>(
      submissionOf: (state) =>
          state is SettingsLoaded ? state.submission : null,
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
          bottomBar: _saveBar(context),
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

  /// Bay counts per group, so the form can explain that out-of-service is per
  /// bay once a map exists. Best effort: without a map the counters stay.
  Future<void> _loadSpotCounts() async {
    final repository = widget.spots;
    if (repository == null) {
      return;
    }
    try {
      final spots = await repository.list();
      if (!mounted) {
        return;
      }
      setState(() {
        _carBays = spots.where((spot) => spot.group == SlotGroup.car).length;
        _carBaysOut = spots
            .where((spot) => spot.group == SlotGroup.car && !spot.active)
            .length;
        _motoBays = spots.where((spot) => spot.group == SlotGroup.moto).length;
        _motoBaysOut = spots
            .where((spot) => spot.group == SlotGroup.moto && !spot.active)
            .length;
      });
    } catch (_) {
      // The counts are explanatory only; the form keeps working.
    }
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
    _carOutOfService.text,
    _motoOutOfService.text,
    _legalPolicy.text,
    _currency,
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
    _carOutOfService.text = settings.carOutOfService.toString();
    _motoOutOfService.text = settings.motoOutOfService.toString();
    _legalPolicy.text = settings.legalPolicy;
    _currency = settings.currency;
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
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.md,
          Space.md,
          Space.xxl,
        ),
        children: [
          _logoSection(context, settings),
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.badge_outlined,
            title: l10n.settingsSectionIdentity,
          ),
          const SizedBox(height: Space.sm),
          TextFormField(
            key: const Key('settings_name'),
            controller: _name,
            maxLength: 80,
            decoration: InputDecoration(labelText: l10n.settingsName),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? l10n.fieldRequired
                : null,
          ),
          const SizedBox(height: Space.md),
          TextFormField(
            key: const Key('settings_address'),
            controller: _address,
            maxLength: 160,
            decoration: InputDecoration(labelText: l10n.settingsAddress),
          ),
          const SizedBox(height: Space.md),
          TextFormField(
            key: const Key('settings_schedule'),
            controller: _schedule,
            maxLength: 120,
            decoration: InputDecoration(labelText: l10n.settingsSchedule),
          ),
          const SizedBox(height: Space.md),
          TextFormField(
            key: const Key('settings_phone'),
            controller: _phone,
            maxLength: 32,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.settingsPhone),
          ),
          const SizedBox(height: Space.md),
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
          const SizedBox(height: Space.md),
          TextFormField(
            key: const Key('settings_whatsapp'),
            controller: _whatsapp,
            maxLength: 32,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.settingsWhatsapp),
          ),
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.grid_view_rounded,
            title: l10n.settingsSectionSpaces,
          ),
          const SizedBox(height: Space.sm),
          TextFormField(
            key: const Key('settings_car_capacity'),
            controller: _carCapacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.settingsCarCapacity,
              helperText: l10n.settingsCapacityHint,
              helperMaxLines: 2,
            ),
            validator: _capacity,
          ),
          const SizedBox(height: Space.md),
          TextFormField(
            key: const Key('settings_moto_capacity'),
            controller: _motoCapacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.settingsMotoCapacity,
              helperText: l10n.settingsCapacityHint,
              helperMaxLines: 2,
            ),
            validator: _capacity,
          ),
          const SizedBox(height: Space.md),
          if (_carBays > 0)
            _MapMaintenanceNote(
              label: l10n.homeCapacityCars,
              bays: _carBaysOut,
            )
          else
            TextFormField(
              key: const Key('settings_car_out_of_service'),
              controller: _carOutOfService,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.settingsCarOutOfService,
                helperText: l10n.settingsOutOfServiceHint,
                helperMaxLines: 2,
              ),
              validator: (value) => _outOfService(value, _carCapacity.text),
            ),
          if (_carBays > 0) const SizedBox(height: Space.md),
          if (_motoBays > 0)
            _MapMaintenanceNote(
              label: l10n.homeCapacityMotos,
              bays: _motoBaysOut,
            )
          else
            TextFormField(
              key: const Key('settings_moto_out_of_service'),
              controller: _motoOutOfService,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.settingsMotoOutOfService,
                helperText: l10n.settingsOutOfServiceHint,
                helperMaxLines: 2,
              ),
              validator: (value) => _outOfService(value, _motoCapacity.text),
            ),
          const SizedBox(height: Space.md),
          TextFormField(
            key: const Key('settings_key_capacity'),
            controller: _keyCapacity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.settingsKeyCapacity,
              helperText: l10n.settingsCapacityHint,
              helperMaxLines: 2,
            ),
            validator: _capacity,
          ),
          const SizedBox(height: Space.md),
          OutlinedButton.icon(
            key: const Key('settings_spots_map'),
            onPressed: () => context.go('/spots'),
            icon: const Icon(Icons.grid_view_rounded),
            label: Text(l10n.spotsTitle),
          ),
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.photo_camera_outlined,
            title: l10n.settingsSectionEvidence,
          ),
          const SizedBox(height: Space.sm),
          TextFormField(
            key: const Key('settings_evidence_retention'),
            controller: _evidenceRetention,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.settingsEvidenceRetention,
              helperText: l10n.settingsEvidenceRetentionHint,
              helperMaxLines: 2,
            ),
            validator: (value) {
              final days = int.tryParse((value ?? '').trim());
              return days == null || days < 0 || days > 3650
                  ? l10n.invalidAmount
                  : null;
            },
          ),
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.chat_outlined,
            title: l10n.settingsSectionMessaging,
          ),
          SwitchListTile(
            key: const Key('settings_whatsapp_auto'),
            contentPadding: EdgeInsets.zero,
            value: _whatsappAuto,
            onChanged: (value) => setState(() => _whatsappAuto = value),
            title: Text(l10n.settingsWhatsappAuto),
            subtitle: Text(l10n.settingsWhatsappAutoHint),
          ),
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.tune,
            title: l10n.settingsSectionPreferences,
          ),
          const SizedBox(height: Space.sm),
          DropdownButtonFormField<String>(
            key: const Key('settings_currency'),
            initialValue: _currency,
            decoration: InputDecoration(
              labelText: l10n.settingsCurrency,
              helperText: l10n.settingsCurrencyHint,
              helperMaxLines: 3,
            ),
            items: [
              DropdownMenuItem(value: 'COP', child: Text(l10n.currencyCop)),
              DropdownMenuItem(value: 'USD', child: Text(l10n.currencyUsd)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _currency = value);
              }
            },
          ),
          const SizedBox(height: Space.lg),
          SectionHeader(
            icon: Icons.gavel_outlined,
            title: l10n.settingsSectionLegal,
          ),
          const SizedBox(height: Space.sm),
          TextFormField(
            key: const Key('settings_legal_policy'),
            controller: _legalPolicy,
            minLines: 8,
            maxLines: 20,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: l10n.settingsLegalPolicy,
              helperText: l10n.settingsLegalPolicyHint,
              helperMaxLines: 2,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              OutlinedButton.icon(
                key: const Key('settings_legal_reset'),
                onPressed: () => _resetLegalPolicy(context),
                icon: const Icon(Icons.restore),
                label: Text(l10n.settingsLegalReset),
              ),
              TextButton.icon(
                key: const Key('settings_legal_preview'),
                onPressed: () => _previewLegalPolicy(context),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(l10n.settingsLegalPreview),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _saveBar(BuildContext context) {
    final l10n = context.l10n;
    final settings = switch (context.watch<SettingsCubit>().state) {
      SettingsLoaded(:final settings) => settings,
      _ => ParkingSettings.defaults(),
    };
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.md,
            Space.sm,
          ),
          child: FilledButton(
            key: const Key('settings_save'),
            onPressed: () => _save(context, settings),
            child: Text(l10n.actionSave),
          ),
        ),
      ),
    );
  }

  Future<void> _resetLegalPolicy(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<SettingsCubit>();
    try {
      final template = await cubit.resetLegalPolicy();
      if (!context.mounted) {
        return;
      }
      setState(() => _legalPolicy.text = template);
      showInfoSnack(context, l10n.settingsLegalResetDone);
    } on Failure catch (failure) {
      if (context.mounted) {
        showErrorSnack(context, l10n.failure(failure));
      }
    }
  }

  Future<void> _previewLegalPolicy(BuildContext context) async {
    final l10n = context.l10n;
    final rendered = renderPolicyTemplate(
      _legalPolicy.text,
      parking: _name.text,
      address: _address.text,
      schedule: _schedule.text,
      phone: _phone.text,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsLegalPreviewTitle),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              rendered.trim().isEmpty ? l10n.settingsLegalEmpty : rendered,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
  }

  Widget _logoSection(BuildContext context, ParkingSettings settings) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<BrandingCubit, BrandingState>(
      builder: (context, branding) {
        final bytes = branding.logoOrNull;
        return Card(
          margin: const EdgeInsets.only(bottom: Space.lg),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(Space.sm),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: bytes == null
                      ? Icon(
                          Icons.local_parking_rounded,
                          size: 36,
                          color: scheme.onPrimaryContainer,
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.sm),
                          child: Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.broken_image_outlined,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.name.isEmpty ? l10n.appTitle : settings.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.settingsLogoSection,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                FilledButton.tonalIcon(
                  onPressed: _uploadLogo,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(l10n.settingsLogoPick),
                ),
              ],
            ),
          ),
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
        carOutOfService: int.tryParse(_carOutOfService.text.trim()) ?? 0,
        motoOutOfService: int.tryParse(_motoOutOfService.text.trim()) ?? 0,
        legalPolicy: _legalPolicy.text.trim(),
        currency: _currency,
      ),
    );
  }

  /// Zero-capacity means "no limit", so an out-of-service count only makes
  /// sense (and is only bounded) when the group has a configured capacity.
  String? _outOfService(String? value, String capacityText) {
    final spaces = int.tryParse((value ?? '0').trim());
    if (spaces == null || spaces < 0 || spaces > 10000) {
      return context.l10n.invalidAmount;
    }
    final capacity = int.tryParse(capacityText.trim()) ?? 0;
    if (capacity > 0 && spaces > capacity) {
      return context.l10n.settingsOutOfServiceTooMany;
    }
    return null;
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

class _MapMaintenanceNote extends StatelessWidget {
  const _MapMaintenanceNote({required this.label, required this.bays});

  final String label;
  final int bays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.build_circle_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              '$label · ${context.l10n.settingsOutOfServiceMapHint(bays)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
