import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
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
  var _seeded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _address = TextEditingController();
    _schedule = TextEditingController();
    _phone = TextEditingController();
    _website = TextEditingController();
    _whatsapp = TextEditingController();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return SubmissionListener<SettingsCubit, SettingsState>(
      submissionOf: (state) => state is SettingsLoaded ? state.submission : null,
      onSuccess: _onSaved,
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
    );
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
  }

  void _onSaved(BuildContext context, Object? result) {
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
      ),
    );
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
