import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/error/failure.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/utils/elapsed.dart';
import '../../../core/utils/vehicle_groups.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/photo_strip.dart';
import '../../../core/widgets/plate_input_field.dart';
import '../../../core/widgets/receipt_card.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../../app/di/injection.dart';
import '../../home/application/dashboard_cubit.dart';
import '../../plate_scanning/application/plate_scanning_cubit.dart';
import '../../plate_scanning/domain/repositories/plate_image_capture.dart';
import '../../plate_scanning/presentation/inline_plate_scan.dart';
import '../../receipt_printing/presentation/receipt_print_sheet.dart';
import '../../reservations/domain/entities/reservation.dart';
import '../../reservations/domain/repositories/reservation_repository.dart';
import '../../vehicles/domain/repositories/vehicle_repository.dart';
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
    this.onMarkExit,
    this.reservations,
    this.vehicles,
  });

  /// Camera port (injected by the router from get_it; fakes in tests).
  final PlateImageCapture capture;

  /// `false` where on-device plate OCR is unavailable (web): the scan
  /// button is hidden and the plate is typed.
  final bool canScan;

  /// Plate to prefill (e.g. from a reservation): the vehicle lookup runs as
  /// soon as the page opens, saving a retype.
  final String? initialPlate;

  /// Opens check-out for an open session (injectable for widget tests).
  final void Function(BuildContext context, String plate)? onMarkExit;

  /// Active holds, so the operator can cancel one when the customer does not
  /// arrive. Optional in tests.
  final ReservationRepository? reservations;

  /// Known plates for the quick suggestions under the field. Optional.
  final VehicleRepository? vehicles;

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
  bool _sessionsOpen = true;
  bool _leftKeys = false;
  List<Reservation> _activeHolds = const [];
  List<String> _knownPlates = const [];
  static const _prefsBox = 'preferences';
  static const _lastPlateKey = 'last_plate';

  bool get _photoLimitReached => _photos.length >= EvidencePolicy.maxPhotos;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<CheckInCubit>().loadOpenSessions());
    unawaited(_loadHolds());
    unawaited(_loadKnownPlates());
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

  Future<void> _loadHolds() async {
    final repository = widget.reservations;
    if (repository == null) {
      return;
    }
    try {
      final holds = await repository.listActive();
      if (mounted) {
        setState(() => _activeHolds = holds);
      }
    } catch (_) {
      // The hold banner is an extra; check-in keeps working without it.
    }
  }

  /// Repeat customers type two letters and pick their plate: no full plate
  /// memory needed from the operator.
  Future<void> _loadKnownPlates() async {
    final repository = widget.vehicles;
    if (repository == null) {
      return;
    }
    try {
      final page = await repository.listPage(offset: 0, limit: 200);
      if (mounted) {
        setState(() {
          _knownPlates = [for (final vehicle in page.items) vehicle.plate];
        });
      }
    } catch (_) {
      // Suggestions are an extra; check-in keeps working without them.
    }
  }

  List<String> _plateSuggestions() {
    final typed = _plateController.text.replaceAll(RegExp(r'\s'), '')
        .toUpperCase();
    if (typed.length < 2) {
      return const [];
    }
    final matches = <String>[];
    for (final plate in _knownPlates) {
      final normalized = plate.toUpperCase();
      if (normalized != typed && normalized.startsWith(typed)) {
        matches.add(plate);
        if (matches.length == 4) {
          break;
        }
      }
    }
    return matches;
  }

  void _pickPlate(String plate) {
    _plateController.value = TextEditingValue(
      text: plate,
      selection: TextSelection.collapsed(offset: plate.length),
    );
    _onPlateChanged(plate);
    _lookupNow();
  }

  Reservation? _holdFor(String plate) {
    final normalized = plate.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final hold in _activeHolds) {
      if (hold.plate.toUpperCase() == normalized) {
        return hold;
      }
    }
    return null;
  }

  Future<void> _cancelHold(Reservation hold) async {
    final l10n = context.l10n;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.reservationCancelTitle,
        body: l10n.reservationCancelBody(hold.plate),
        confirmLabel: l10n.reservationCancel,
        destructive: true,
      ),
    );
    final repository = widget.reservations;
    if (!confirmed || !mounted || repository == null) {
      return;
    }
    try {
      await repository.cancel(hold.id);
      await _loadHolds();
      if (mounted) {
        showInfoSnack(context, l10n.reservationCancelled);
      }
    } on Failure catch (failure) {
      if (mounted) {
        showErrorSnack(context, context.l10n.failure(failure));
      }
    }
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
        leftKeys: _leftKeys,
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
      _leftKeys = false;
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
        unawaited(_loadHolds());
    unawaited(_loadKnownPlates());
        unawaited(context.read<DashboardCubit>().load());
        final message = context.l10n.checkInSuccess(result.plate);
        SemanticsService.announce(message, Directionality.of(context));
        showInfoSnack(context, message);
        unawaited(_showReceipt(context, result));
      case SubmissionFailed(:final message, :final failure):
        showErrorSnack(context, context.l10n.errorText(message, failure));
      default:
        break;
    }
  }

  /// The ticket the customer keeps: it carries the exit QR and can be printed
  /// right away.
  Future<void> _showReceipt(BuildContext context, ParkingSession result) async {
    final data = ReceiptData(
      kind: ReceiptKind.checkIn,
      plate: result.plate,
      entryTime: result.entryTime,
      photoCount: result.photoCount,
      pendingSync: result.status == ParkingSessionStatus.pendingSync,
    );
    await showReceipt(
      context,
      data,
      onPrint: () => showReceiptPrintSheet(context, data),
    );
    if (mounted) {
      _plateFocus.requestFocus();
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
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _SessionsHeader(
                    open: _sessionsOpen,
                    onToggle: () =>
                        setState(() => _sessionsOpen = !_sessionsOpen),
                  ),
                ),
              ),
              if (_sessionsOpen)
                _OpenSessionsSliver(onMarkExit: widget.onMarkExit),
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

  /// Open session for the typed plate, if the local list knows it.
  ParkingSession? _openSessionFor(String plate) {
    final normalized = plate.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final state = context.watch<CheckInCubit>().state;
      for (final session in state.sessions) {
        if (session.plate.toUpperCase() == normalized) {
          return session;
        }
      }
    } on ProviderNotFoundException {
      // Isolated tests may not provide the sessions cubit.
    }
    return null;
  }

  Widget _buildFormFields(BuildContext context, VehicleLookupState lookup) {
    final l10n = context.l10n;
    final openSession = _openSessionFor(_plateController.text);
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
        PlateInputField(
          controller: _plateController,
          focusNode: _plateFocus,
          onChanged: _onPlateChanged,
          onSubmitted: (_) => _lookupNow(),
        ),
        if (_plateSuggestions() case final suggestions
            when suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final plate in suggestions)
                  ActionChip(
                    avatar: const Icon(Icons.history, size: 18),
                    label: Text(plate),
                    onPressed: () => _pickPlate(plate),
                  ),
              ],
            ),
          ),
        if (openSession != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.checkInAlreadyInside(openSession.plate),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
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
        if (_holdFor(_plateController.text) case final hold?) ...[
          const SizedBox(height: 8),
          _HoldBanner(hold: hold, onCancel: () => unawaited(_cancelHold(hold))),
        ],
        const SizedBox(height: 8),
        VehicleLookupSection(state: lookup, registration: _buildRegistration),
        SwitchListTile(
          key: const Key('check_in_left_keys'),
          contentPadding: EdgeInsets.zero,
          value: _leftKeys,
          onChanged: (value) => setState(() => _leftKeys = value),
          title: Text(l10n.checkInLeftKeys),
          subtitle: Text(l10n.checkInLeftKeysHint),
          secondary: const Icon(Icons.key_outlined),
        ),
        const SizedBox(height: 8),
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
      final full = <int>{
        for (final category in state.categories)
          if (category.isFull) category.categoryId,
      };
      // With group spaces configured, a category is only blocked when its
      // whole group (cars + pickups, or motorcycles) is full.
      if (state.capacity.carsFull) {
        full.addAll([
          for (final category in state.categories)
            if (isCarGroup(category.name)) category.categoryId,
        ]);
      }
      if (state.capacity.motosFull) {
        full.addAll([
          for (final category in state.categories)
            if (isMotoGroup(category.name)) category.categoryId,
        ]);
      }
      return full;
    } on ProviderNotFoundException {
      return const {};
    }
  }

  /// Remaining spaces for the category's group, when the site configured it.
  /// `null` means "no limit / unknown" and the option stays plain.
  String? _availability(String categoryName) {
    try {
      final state = context.watch<DashboardCubit>().state;
      if (state is! DashboardLoaded) {
        return null;
      }
      final capacity = state.capacity;
      final int? remaining;
      if (isCarGroup(categoryName) && capacity.carCapacity > 0) {
        remaining = capacity.carCapacity -
            capacity.carOpen -
            capacity.carReserved;
      } else if (isMotoGroup(categoryName) && capacity.motoCapacity > 0) {
        remaining = capacity.motoCapacity -
            capacity.motoOpen -
            capacity.motoReserved;
      } else {
        remaining = null;
      }
      if (remaining == null) {
        return null;
      }
      return remaining <= 0
          ? context.l10n.categoryNoSpots
          : context.l10n.categorySpotsLeft(remaining);
    } on ProviderNotFoundException {
      return null;
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
                          : [
                              category.name,
                              ?_availability(category.name),
                            ].join(' · '),
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

/// Collapsible "vehicles inside" header: shows the count and hides the list
/// when the operator is focused on the form.
class _SessionsHeader extends StatelessWidget {
  const _SessionsHeader({required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            key: const Key('sessions_toggle'),
            borderRadius: BorderRadius.circular(Radii.sm),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.sm,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_parking_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: BlocBuilder<CheckInCubit, CheckInState>(
                      buildWhen: (previous, current) =>
                          previous.sessions.length != current.sessions.length,
                      builder: (context, state) => Row(
                        children: [
                          Flexible(
                            child: Text(
                              l10n.openSessionsTitle,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (state.sessions.isNotEmpty) ...[
                            const SizedBox(width: Space.sm),
                            Badge(label: Text('${state.sessions.length}')),
                          ],
                        ],
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0 : -0.25,
                    duration: Motion.short,
                    child: const Icon(Icons.expand_more, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Lazily built list of open sessions; rebuilds only when the list (or its
/// load status) changes, never on form submissions.
void _markExit(BuildContext context, String plate) => context.push(
  '/check-out?scan=${Uri.encodeQueryComponent(plate)}',
);

class _OpenSessionsSliver extends StatelessWidget {
  const _OpenSessionsSliver({this.onMarkExit});

  final void Function(BuildContext context, String plate)? onMarkExit;

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
              _SessionTile(
                session: state.sessions[index],
                onMarkExit: onMarkExit,
              ),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, this.onMarkExit});

  final ParkingSession session;
  final void Function(BuildContext context, String plate)? onMarkExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      title: Text(session.plate),
      subtitle: Text(
        '${l10n.sessionEntry(Formatters.dateTime(session.entryTime))}'
        ' · ${elapsedLabel(l10n, session.entryTime)}'
        ' · ${l10n.sessionPhotos(session.photoCount)}'
        '${session.leftKeys ? ' · ${l10n.checkInLeftKeysShort}' : ''}',
      ),
      trailing: session.status == ParkingSessionStatus.pendingSync
          ? Chip(label: Text(l10n.statusPendingSync))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: l10n.receiptView,
                  onPressed: () => _viewReceipt(context),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: l10n.markExit,
                  onPressed: () => (onMarkExit ?? _markExit)(
                    context,
                    session.plate,
                  ),
                ),
              ],
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

class _HoldBanner extends StatelessWidget {
  const _HoldBanner({required this.hold, required this.onCancel});

  final Reservation hold;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.xs, Space.sm),
        child: Row(
          children: [
            Icon(
              Icons.event_available,
              size: 20,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.checkInHoldTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    l10n.reservationUntil(
                      Formatters.dateTime(hold.reservedUntil.toLocal()),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onCancel,
              child: Text(l10n.reservationCancel),
            ),
          ],
        ),
      ),
    );
  }
}
