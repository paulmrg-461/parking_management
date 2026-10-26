import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/utils/elapsed.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/widgets/photo_strip.dart';
import '../../../core/widgets/receipt_card.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../../app/di/injection.dart';
import '../../home/application/dashboard_cubit.dart';
import '../../plate_scanning/application/plate_scanning_cubit.dart';
import '../../plate_scanning/domain/repositories/plate_image_capture.dart';
import '../../plate_scanning/presentation/inline_plate_scan.dart';
import '../../receipt_printing/presentation/receipt_print_sheet.dart';
import '../../notifications/presentation/notification_bell.dart';
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
  const CheckInPage({
    super.key,
    required this.capture,
    this.canScan = true,
    this.initialPlate,
  });

  /// Camera port (injected by the router from get_it; fakes in tests).
  final PlateImageCapture capture;

  /// `false` where on-device plate OCR is unavailable (web): the scan
  /// button is hidden and the plate is typed.
  final bool canScan;

  /// Plate to prefill (e.g. from a reservation): the vehicle lookup runs as
  /// soon as the page opens, saving a retype.
  final String? initialPlate;

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
  String? _lastPlate;
  static const _prefsBox = 'preferences';
  static const _lastPlateKey = 'last_plate';

  bool get _photoLimitReached => _photos.length >= EvidencePolicy.maxPhotos;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<CheckInCubit>().loadOpenSessions());
    // Fresh capacity snapshot so full categories are disabled in the
    // registration dropdown even on a deep link.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      try {
        unawaited(context.read<DashboardCubit>().load());
      } on ProviderNotFoundException {
        // Isolated tests may not provide the dashboard cubit.
      }
      _restoreLastPlate();
      _prefillPlate();
    });
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

  void _prefillPlate() {
    final plate = widget.initialPlate?.trim();
    if (plate == null || plate.isEmpty) {
      return;
    }
    _plateController.text = plate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _lookupNow();
      }
    });
  }

  void _restoreLastPlate() {
    if (!serviceLocator.isRegistered<KeyValueStore>()) {
      return;
    }
    final stored = serviceLocator<KeyValueStore>().get(
      _prefsBox,
      _lastPlateKey,
    );
    if (stored is String && stored.isNotEmpty && mounted) {
      setState(() => _lastPlate = stored);
    }
  }

  Future<void> _rememberLastPlate(String plate) async {
    if (!serviceLocator.isRegistered<KeyValueStore>()) {
      return;
    }
    try {
      await serviceLocator<KeyValueStore>().put(
        _prefsBox,
        _lastPlateKey,
        plate,
      );
    } catch (_) {
      // A preference is not worth an error dialog.
    }
  }

  void _repeatLastPlate() {
    final plate = _lastPlate;
    if (plate == null) {
      return;
    }
    setState(() => _plateController.text = plate);
    _lookupNow();
    _plateFocus.requestFocus();
  }

  void _onPlateChanged(String _) {
    setState(() {});
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
        setState(() => _lastPlate = result.plate);
        unawaited(_rememberLastPlate(result.plate));
        unawaited(context.read<DashboardCubit>().load());
        final message = context.l10n.checkInSuccess(result.plate);
        SemanticsService.announce(message, Directionality.of(context));
        showInfoSnack(context, message);
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
        actions: const [NotificationBell(), SyncBadge()],
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
        if (_lastPlate != null && _plateController.text.trim().isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.replay, size: 18),
              label: Text(l10n.checkInRepeat(_lastPlate!)),
              onPressed: _repeatLastPlate,
            ),
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

  /// Category ids that already reached their capacity (reservations
  /// included). Empty when the dashboard snapshot is unavailable.
  Set<int> _fullCategories(BuildContext context) {
    try {
      final state = context.watch<DashboardCubit>().state;
      if (state is! DashboardLoaded) {
        return const {};
      }
      return {
        for (final category in state.categories)
          if (category.isFull) category.categoryId,
      };
    } on ProviderNotFoundException {
      return const {};
    }
  }

  Widget _buildRegistration(VehicleLookupNotFound lookup) {
    final l10n = context.l10n;
    final full = _fullCategories(context);
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
              helperText: full.isEmpty
                  ? l10n.categoryRequiredHelper
                  : l10n.categoryFullHint,
            ),
            items: [
              for (final category in lookup.categories)
                if (category.id != null)
                  DropdownMenuItem(
                    value: category.id,
                    enabled: !full.contains(category.id),
                    child: Text(
                      full.contains(category.id)
                          ? '${category.name} · ${l10n.errorCategoryFull}'
                          : category.name,
                    ),
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
                state.loadError == null
                    ? context.l10n.openSessionsEmpty
                    : context.l10n.errorText(
                        state.loadError!,
                        state.loadFailure,
                      ),
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
        ' · ${elapsedLabel(l10n, session.entryTime)}'
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
