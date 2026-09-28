import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/submission.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../plate_scanning/domain/repositories/plate_image_capture.dart';
import '../application/check_in_cubit.dart';
import '../application/vehicle_lookup_cubit.dart';
import '../domain/entities/new_vehicle_info.dart';
import '../domain/entities/parking_session.dart';
import '../domain/evidence_policy.dart';
import 'widgets/vehicle_lookup_section.dart';

/// Captures a check-in: a scanned or manually entered plate plus optional
/// evidence photos (max [EvidencePolicy.maxPhotos]), submitted to open a new
/// parking session. Also shows the currently open sessions. The plate is
/// looked up (debounced) so a registered vehicle is shown read-only and an
/// unknown one can be registered with the check-in.
class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key, required this.capture, this.canScan = true});

  /// Camera port (injected by the router from get_it; fakes in tests).
  final PlateImageCapture capture;

  /// `false` where on-device plate OCR is unavailable (web): the scan
  /// button is hidden and the plate is typed.
  final bool canScan;

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

/// A captured photo plus its bytes, decoded once for the thumbnail.
class _Photo {
  const _Photo(this.file, this.bytes);

  final XFile file;
  final Uint8List bytes;
}

class _CheckInPageState extends State<CheckInPage> {
  static const _lookupDebounce = Duration(milliseconds: 500);
  static const _thumbnailSize = 80.0;

  final _plateController = TextEditingController();
  final _colorController = TextEditingController();
  final _brandController = TextEditingController();
  final List<_Photo> _photos = [];
  Timer? _debounce;
  int? _categoryId;

  bool get _photoLimitReached => _photos.length >= EvidencePolicy.maxPhotos;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<CheckInCubit>().loadOpenSessions());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _plateController.dispose();
    _colorController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _scanPlate(BuildContext context) async {
    final result = await context.push<String>('/scan');
    if (result != null && mounted) {
      setState(() => _plateController.text = result);
      _lookupNow();
    }
  }

  void _onPlateChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(_lookupDebounce, _lookupNow);
  }

  void _lookupNow() {
    _debounce?.cancel();
    unawaited(context.read<VehicleLookupCubit>().lookup(_plateController.text));
  }

  Future<void> _addPhoto() async {
    if (_photoLimitReached) {
      return;
    }
    final image = await widget.capture.capture();
    if (image == null) {
      return;
    }
    final bytes = await image.readAsBytes();
    if (mounted && !_photoLimitReached) {
      setState(() => _photos.add(_Photo(image, bytes)));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _submit(BuildContext context, VehicleLookupState lookup) {
    unawaited(
      context.read<CheckInCubit>().submitCheckIn(
        plate: _plateController.text,
        photos: [for (final photo in _photos) photo.file],
        newVehicle: lookup is VehicleLookupNotFound ? _newVehicleInfo() : null,
      ),
    );
  }

  NewVehicleInfo? _newVehicleInfo() {
    final categoryId = _categoryId;
    if (categoryId == null) {
      return null;
    }
    return NewVehicleInfo(
      categoryId: categoryId,
      color: _optionalText(_colorController),
      brand: _optionalText(_brandController),
    );
  }

  String? _optionalText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  bool _canSubmit(bool submitting, VehicleLookupState lookup) {
    if (submitting || lookup is VehicleLookupLoading) {
      return false;
    }
    return lookup is! VehicleLookupNotFound || _categoryId != null;
  }

  void _resetForm() {
    _debounce?.cancel();
    _plateController.clear();
    _colorController.clear();
    _brandController.clear();
    setState(() {
      _photos.clear();
      _categoryId = null;
    });
    context.read<VehicleLookupCubit>().reset();
  }

  void _onSubmission(BuildContext context, CheckInState state) {
    switch (state.submission) {
      case SubmissionSucceeded<ParkingSession>(:final result):
        _resetForm();
        showInfoSnack(context, 'Check-in created for ${result.plate}');
      case SubmissionFailed(:final message):
        showErrorSnack(context, message);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in'),
        actions: const [SyncBadge()],
      ),
      body: BlocListener<CheckInCubit, CheckInState>(
        listenWhen: (previous, current) =>
            submissionJustFailed(previous.submission, current.submission) ||
            submissionJustSucceeded(previous.submission, current.submission),
        listener: _onSubmission,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(child: _buildForm(context)),
            ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _SessionsHeader()),
            ),
            const _OpenSessionsSliver(),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return BlocConsumer<VehicleLookupCubit, VehicleLookupState>(
      listenWhen: (previous, current) => current is VehicleLookupNotFound,
      listener: (context, _) => setState(() => _categoryId = null),
      builder: (context, lookup) => _buildFormFields(context, lookup),
    );
  }

  Widget _buildFormFields(BuildContext context, VehicleLookupState lookup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.canScan) ...[
          FilledButton.icon(
            onPressed: () => _scanPlate(context),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scan plate'),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _plateController,
          decoration: const InputDecoration(labelText: 'Plate'),
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onChanged: _onPlateChanged,
          onSubmitted: (_) => _lookupNow(),
        ),
        const SizedBox(height: 8),
        VehicleLookupSection(state: lookup, registration: _buildRegistration),
        const SizedBox(height: 16),
        _buildPhotos(context),
        const SizedBox(height: 16),
        BlocSelector<CheckInCubit, CheckInState, bool>(
          selector: (state) => state.submission.isInProgress,
          builder: (context, submitting) =>
              _buildSubmit(context, submitting, lookup),
        ),
      ],
    );
  }

  Widget _buildPhotos(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Evidence photos (${_photos.length}/${EvidencePolicy.maxPhotos})'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _photos.length; i++)
              _buildThumbnail(context, i),
            OutlinedButton(
              onPressed: _photoLimitReached ? null : _addPhoto,
              child: const Icon(Icons.add_a_photo, semanticLabel: 'Add photo'),
            ),
          ],
        ),
        if (_photoLimitReached)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Maximum ${EvidencePolicy.maxPhotos} photos per check-in',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildThumbnail(BuildContext context, int index) {
    final cacheWidth = (_thumbnailSize * MediaQuery.devicePixelRatioOf(context))
        .round();
    return SizedBox(
      width: _thumbnailSize,
      height: _thumbnailSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.memory(
              _photos[index].bytes,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              gaplessPlayback: true,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () => _removePhoto(index),
              child: const CircleAvatar(
                radius: 10,
                child: Icon(
                  Icons.close,
                  size: 14,
                  semanticLabel: 'Remove photo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmit(
    BuildContext context,
    bool submitting,
    VehicleLookupState lookup,
  ) {
    return FilledButton(
      onPressed: _canSubmit(submitting, lookup)
          ? () => _submit(context, lookup)
          : null,
      child: submitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Submit check-in'),
    );
  }

  Widget _buildRegistration(VehicleLookupNotFound lookup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'New vehicle',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: ObjectKey(lookup),
          initialValue: _categoryId,
          decoration: const InputDecoration(
            labelText: 'Category',
            helperText: 'Required to register this plate',
          ),
          items: [
            for (final category in lookup.categories)
              if (category.id != null)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _colorController,
          decoration: const InputDecoration(labelText: 'Color (optional)'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _brandController,
          decoration: const InputDecoration(labelText: 'Brand (optional)'),
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }
}

class _SessionsHeader extends StatelessWidget {
  const _SessionsHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 32),
        Text('Open sessions', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
      ],
    );
  }
}

/// Lazily built list of open sessions; rebuilds only when the list (or its
/// load status) changes, never on form submissions.
class _OpenSessionsSliver extends StatelessWidget {
  const _OpenSessionsSliver();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckInCubit, CheckInState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.sessions != current.sessions,
      builder: (context, state) {
        if (state.status == SessionsStatus.loading && state.sessions.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (state.sessions.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(state.loadError ?? 'No open sessions'),
            ),
          );
        }
        return SliverList.builder(
          itemCount: state.sessions.length,
          itemBuilder: (context, index) =>
              _SessionTile(session: state.sessions[index]),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final ParkingSession session;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(session.plate),
      subtitle: Text(
        'Entry: ${session.entryTime.toLocal()} · Photos: ${session.photoCount}',
      ),
      trailing: session.status == ParkingSessionStatus.pendingSync
          ? const Chip(label: Text('Pending sync'))
          : null,
    );
  }
}
