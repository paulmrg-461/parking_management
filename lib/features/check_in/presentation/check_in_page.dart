import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/photo_strip.dart';
import '../../../core/widgets/receipt_card.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../home/application/dashboard_cubit.dart';
import '../../plate_scanning/application/plate_scanning_cubit.dart';
import '../../plate_scanning/domain/repositories/plate_image_capture.dart';
import '../../plate_scanning/presentation/inline_plate_scan.dart';
import '../../receipt_printing/presentation/receipt_print_sheet.dart';
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

  final _plateController = TextEditingController();
  final _plateFocus = FocusNode();
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
    _plateFocus.dispose();
    _colorController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _scanPlate() async {
    final cubit = context.read<PlateScanningCubit>();
    final image = await captureAndScan(cubit, widget.capture);
    if (image != null && mounted && !_photoLimitReached) {
      final bytes = await image.readAsBytes();
      if (mounted && !_photoLimitReached) {
        setState(() => _photos.add(_Photo(image, bytes)));
      }
    }
  }

  void _onPlateDetected(String plate) {
    if (!mounted) {
      return;
    }
    setState(() => _plateController.text = plate);
    _lookupNow();
  }

  void _onPlateUnreadable(String message, String prefill) {
    if (!mounted) {
      return;
    }
    if (prefill.isNotEmpty) {
      setState(() => _plateController.text = prefill);
    }
    _plateFocus.requestFocus();
    showErrorSnack(context, message);
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
        HapticFeedback.mediumImpact();
        _resetForm();
        _plateFocus.requestFocus();
        unawaited(context.read<DashboardCubit>().load());
        showInfoSnack(context, context.l10n.checkInSuccess(result.plate));
      case SubmissionFailed(:final message, :final failure):
        showErrorSnack(context, context.l10n.errorText(message, failure));
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.checkInTitle),
        actions: const [SyncBadge()],
      ),
      body: PlateScanListener(
        onDetected: _onPlateDetected,
        onUnreadable: _onPlateUnreadable,
        child: BlocListener<CheckInCubit, CheckInState>(
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
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.canScan) ...[
          Tooltip(
            message: l10n.plateScanTooltip,
            child: FilledButton.icon(
              onPressed: _scanPlate,
              icon: const Icon(Icons.camera_alt),
              label: Text(l10n.plateLabel),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _plateController,
          focusNode: _plateFocus,
          decoration: InputDecoration(labelText: l10n.plateLabel),
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onChanged: _onPlateChanged,
          onSubmitted: (_) => _lookupNow(),
        ),
        const SizedBox(height: 8),
        VehicleLookupSection(state: lookup, registration: _buildRegistration),
        const SizedBox(height: 16),
        PhotoStrip(
          photos: [for (final photo in _photos) photo.bytes],
          max: EvidencePolicy.maxPhotos,
          onAdd: _addPhoto,
          onRemove: _removePhoto,
        ),
        const SizedBox(height: 16),
        BlocSelector<CheckInCubit, CheckInState, bool>(
          selector: (state) => state.submission.isInProgress,
          builder: (context, submitting) =>
              _buildSubmit(context, submitting, lookup),
        ),
      ],
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
          : Text(context.l10n.checkInSubmit),
    );
  }

  Widget _buildRegistration(VehicleLookupNotFound lookup) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.newVehicle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        if (lookup.categories.isEmpty)
          Text(
            l10n.categoriesEmpty,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else
          DropdownButtonFormField<int>(
            key: ObjectKey(lookup),
            initialValue: _categoryId,
            decoration: InputDecoration(
              labelText: l10n.fieldCategory,
              helperText: l10n.categoryRequiredHelper,
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
          decoration: InputDecoration(labelText: l10n.colorOptional),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _brandController,
          decoration: InputDecoration(labelText: l10n.brandOptional),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          context.l10n.openSessionsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
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
              child: Text(
                state.loadError ?? context.l10n.openSessionsEmpty,
              ),
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
    final l10n = context.l10n;
    return ListTile(
      title: Text(session.plate),
      subtitle: Text(
        '${l10n.sessionEntry(Formatters.dateTime(session.entryTime))}'
        ' · ${l10n.sessionPhotos(session.photoCount)}',
      ),
      trailing: session.status == ParkingSessionStatus.pendingSync
          ? Chip(label: Text(l10n.statusPendingSync))
          : IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: l10n.receiptView,
              onPressed: () => _viewReceipt(context),
            ),
      onTap: () => _viewReceipt(context),
    );
  }

  void _viewReceipt(BuildContext context) {
    final data = ReceiptData(
      kind: ReceiptKind.checkIn,
      plate: session.plate,
      entryTime: session.entryTime,
      photoCount: session.photoCount,
      pendingSync: session.status == ParkingSessionStatus.pendingSync,
    );
    showReceipt(
      context,
      data,
      onPrint: () => showReceiptPrintSheet(context, data),
    );
  }
}
