import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/injection.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/realtime/local_activity.dart';
import '../../../core/state/submission.dart';
import '../../../core/qr/qr_decoder.dart';
import '../../../core/qr/qr_scan_page.dart';
import '../../../core/utils/elapsed.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/receipt_card.dart';
import '../../../core/widgets/plate_keypad.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/entities/user.dart';
import '../../plate_scanning/domain/repositories/plate_image_capture.dart';
import '../../home/application/dashboard_cubit.dart';
import '../../shifts/application/shift_cubit.dart';
import '../../receipt_printing/presentation/receipt_print_sheet.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../application/check_out_cubit.dart';
import '../domain/entities/check_out_receipt.dart';
import '../../../core/receipt/payment_method.dart';
import '../../../core/storage/key_value_store.dart';
import '../domain/entities/open_session.dart';
import 'payment_method_dialog.dart';

/// Lists currently open parking sessions (plates resolved by the cubit),
/// lets an operator search by plate (debounced in the cubit) and close one
/// out, showing a receipt on success. Long lists page in on scroll.
class CheckOutPage extends StatefulWidget {
  const CheckOutPage({
    super.key,
    this.initialQuery,
    this.scanPlate,
    this.capture,
    this.qrDecoder,
    this.scanQr,
  });

  /// Plate to filter by (e.g. arriving from the vehicle history).
  final String? initialQuery;

  /// Plate just scanned with the shell QR action: resolve it and open its
  /// payment dialog as soon as the page mounts.
  final String? scanPlate;

  /// Camera capture + QR reader for the receipt code. Optional so tests can
  /// omit the scanner (the field still accepts a USB reader).
  final PlateImageCapture? capture;
  final QrDecoder? qrDecoder;

  /// Test seam: returns the payload the live scanner read (or null to cancel).
  final Future<String?> Function(BuildContext context)? scanQr;

  @override
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {
  static const _prefsBox = 'preferences';
  static const _lastPaymentKey = 'last_payment_method';

  final _searchController = TextEditingController();
  PaymentMethod? _rememberedMethod;
  PaymentMethod? _pendingMethod;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<CheckOutCubit>().loadOpenSessions());
    _restoreRememberedMethod();
    final query = widget.initialQuery?.trim();
    if (query != null && query.isNotEmpty) {
      _searchController.text = query;
      context.read<CheckOutCubit>().search(query);
    }
    final scan = widget.scanPlate?.trim();
    if (scan != null && scan.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_resolveAndOpen(context, scan));
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// The last method the operator charged with, so a fleet that always pays
  /// the same way does not re-pick it every time. A monthly pass is never
  /// preselected without an active pass (the server would reject it).
  void _restoreRememberedMethod() {
    if (!serviceLocator.isRegistered<KeyValueStore>()) {
      return;
    }
    final stored = serviceLocator<KeyValueStore>().get(
      _prefsBox,
      _lastPaymentKey,
    );
    if (stored is String && stored.isNotEmpty) {
      setState(() => _rememberedMethod = paymentMethodFromWire(stored));
    }
  }

  void _chooseMethod(PaymentMethod method) {
    // Persisted only once the server confirms the check-out.
    _pendingMethod = method;
  }

  Future<void> _rememberMethod(PaymentMethod method) async {
    if (!serviceLocator.isRegistered<KeyValueStore>()) {
      return;
    }
    try {
      await serviceLocator<KeyValueStore>().put(
        _prefsBox,
        _lastPaymentKey,
        method.wire,
      );
    } catch (_) {
      // A preference is not worth an error dialog.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.checkOutTitle),
        actions: const [NotificationBell(), SyncBadge()],
      ),
      body: BlocListener<CheckOutCubit, CheckOutState>(
        listenWhen: (previous, current) =>
            submissionJustFailed(
              _submissionOf(previous),
              _submissionOf(current),
            ) ||
            submissionJustSucceeded(
              _submissionOf(previous),
              _submissionOf(current),
            ),
        listener: _onSubmission,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SearchField(
                      label: context.l10n.searchPlate,
                      controller: _searchController,
                      onChanged: context.read<CheckOutCubit>().search,
                      onSubmitted: (value) =>
                          unawaited(_resolveAndOpen(context, value)),
                      onKeypad: () => showPlateKeypad(
                        context,
                        controller: _searchController,
                        onChanged: (value) {
                          context.read<CheckOutCubit>().search(value);
                          if (mounted) {
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                  if (!kIsWeb ||
                      (widget.capture != null && widget.qrDecoder != null)) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: context.l10n.checkOutScanQr,
                      onPressed: () => unawaited(_scanQr(context)),
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                  ],
                ],
              ),
            ),
            const _ShiftBanner(),
            Expanded(
              child: _SessionsList(
                rememberedMethod: _rememberedMethod,
                onMethodChosen: _chooseMethod,
                onCheckOut: _startCheckout,
                canReprint: _canDiscount(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Submission? _submissionOf(CheckOutState state) =>
      state is CheckOutLoaded ? state.submission : null;

  void _onSubmission(BuildContext context, CheckOutState state) {
    switch (_submissionOf(state)) {
      case SubmissionSucceeded<CheckOutReceipt>(:final result):
        LocalActivity.remember('check_out', result.id);
        final method = _pendingMethod;
        _pendingMethod = null;
        if (method != null) {
          setState(() => _rememberedMethod = method);
          unawaited(_rememberMethod(method));
        }
        SemanticsService.announce(
          '${context.l10n.receiptDoneTitle}: ${result.plate}',
          Directionality.of(context),
        );
        unawaited(context.read<DashboardCubit>().load());
        _refreshShift(context);
        unawaited(_showReceipt(context, result));
      case SubmissionFailed(:final message, :final failure):
        showErrorSnack(context, context.l10n.errorText(message, failure));
      default:
        break;
    }
  }

  void _refreshShift(BuildContext context) {
    try {
      unawaited(context.read<ShiftCubit>().load());
    } on ProviderNotFoundException {
      // Isolated tests may not provide the shell-level shift cubit.
    }
  }

  bool _canDiscount(BuildContext context) {
    try {
      final auth = context.read<AuthCubit>();
      return switch (auth.state) {
        AuthAuthenticated(:final session) =>
          session.user.role == UserRole.admin,
        _ => false,
      };
    } on ProviderNotFoundException {
      return false;
    }
  }

  Future<void> _startCheckout(
    BuildContext context,
    OpenSession session,
    String plate,
  ) async {
    final cubit = context.read<CheckOutCubit>();
    final preview = await cubit.preview(session.id);
    if (!context.mounted) {
      return;
    }
    final choice = await showCheckoutDialog(
      context,
      plate: plate,
      canDiscount: _canDiscount(context),
      preview: preview,
      initialMethod: (preview?.hasPass ?? false)
          ? PaymentMethod.monthlyPass
          : _basePaymentMethod(_rememberedMethod),
    );
    if (choice == null) {
      return;
    }
    _chooseMethod(choice.method);
    await cubit.checkOut(
      session.id,
      paymentMethod: choice.method.wire,
      discountAmount: choice.discountAmount,
      discountReason: choice.discountReason,
      lostTicket: choice.lostTicket,
      lostTicketReason: choice.lostTicketReason,
    );
  }

  /// Scans the QR printed on a receipt: live camera on mobile, photo picker on
  /// web (where the USB reader is the usual path).
  Future<void> _scanQr(BuildContext context) async {
    final payload =
        await (widget.scanQr?.call(context) ?? _scanPayload(context));
    if (!context.mounted) {
      return;
    }
    final plate = payload == null ? null : plateFromQrPayload(payload);
    if (plate == null) {
      if (payload != null) {
        showInfoSnack(context, context.l10n.checkOutQrUnreadable);
      }
      return;
    }
    await _resolveAndOpen(context, plate);
  }

  Future<String?> _scanPayload(BuildContext context) async {
    if (!kIsWeb) {
      return scanQrWithCamera(context);
    }
    final capture = widget.capture;
    final decoder = widget.qrDecoder;
    if (capture == null || decoder == null) {
      return null;
    }
    try {
      final file = await capture.capture();
      if (file == null) {
        return null;
      }
      return await decoder.decode(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  /// Resolves a scanned or typed plate on the server and opens its payment
  /// dialog when exactly one open session matches (USB QR readers type the
  /// plate and send Enter).
  Future<void> _resolveAndOpen(BuildContext context, String rawPlate) async {
    final cubit = context.read<CheckOutCubit>();
    final plate = rawPlate.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (plate.isEmpty) {
      return;
    }
    _searchController.text = plate;
    cubit.search(plate);
    final session = await cubit.resolvePlate(plate);
    if (!context.mounted) {
      return;
    }
    if (session == null) {
      showInfoSnack(context, context.l10n.checkOutQrNoSession(plate));
      return;
    }
    final state = cubit.state;
    final resolved = state is CheckOutLoaded ? state.plateOf(session) : plate;
    await _startCheckout(context, session, resolved);
  }

  Future<void> _showReceipt(BuildContext context, CheckOutReceipt receipt) {
    final data = _receiptData(receipt);
    return showReceiptSummary(
      context,
      data,
      onPrint: () => showReceiptPrintSheet(context, data),
      nextActionLabel: context.l10n.receiptNewCharge,
      onNextAction: () {
        // Back to a clean list with the cursor ready for the next plate.
        if (!resetActiveSearchField()) {
          context.read<CheckOutCubit>().search('');
        }
      },
    );
  }

  ReceiptData _receiptData(CheckOutReceipt receipt) => ReceiptData(
    kind: ReceiptKind.checkOut,
    plate: receipt.plate,
    entryTime: receipt.entryTime,
    exitTime: receipt.exitTime,
    amountCharged: receipt.amountCharged,
    ticketNumber: receipt.ticketNumber,
    paymentMethod: receipt.paymentMethod,
    discountAmount: receipt.discountAmount,
    discountReason: receipt.discountReason,
    pendingSync: receipt.pendingSync,
  );
}

/// Rebuilds only when what it renders changes (not on submission status).
class _SessionsList extends StatelessWidget {
  const _SessionsList({
    required this.rememberedMethod,
    required this.onMethodChosen,
    required this.onCheckOut,
    required this.canReprint,
  });

  final PaymentMethod? rememberedMethod;
  final ValueChanged<PaymentMethod> onMethodChosen;
  final bool canReprint;
  final Future<void> Function(
    BuildContext context,
    OpenSession session,
    String plate,
  )
  onCheckOut;

  static const _loadMoreThreshold = 200.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckOutCubit, CheckOutState>(
      buildWhen: (previous, current) =>
          previous is! CheckOutLoaded ||
          current is! CheckOutLoaded ||
          previous.visible != current.visible ||
          previous.plates != current.plates ||
          previous.hasMore != current.hasMore ||
          previous.loadingMore != current.loadingMore,
      builder: (context, state) => switch (state) {
        CheckOutInitial() || CheckOutLoading() => const SkeletonList(),
        CheckOutFailure(:final message, :final failure) => ErrorState(
          message: context.l10n.errorText(message, failure),
          onRetry: () =>
              unawaited(context.read<CheckOutCubit>().loadOpenSessions()),
        ),
        final CheckOutLoaded loaded => _buildList(context, loaded),
      },
    );
  }

  Widget _buildList(BuildContext context, CheckOutLoaded state) {
    if (state.visible.isEmpty) {
      final query = state.query;
      return EmptyState(
        message: query.isEmpty
            ? context.l10n.openSessionsEmpty
            : context.l10n.checkOutNoMatch(query),
        icon: query.isEmpty ? Icons.local_parking_outlined : Icons.search_off,
        action: query.isEmpty
            ? null
            : TextButton.icon(
                onPressed: () {
                  context.read<CheckOutCubit>().search('');
                  resetActiveSearchField();
                },
                icon: const Icon(Icons.clear),
                label: Text(context.l10n.checkOutClearSearch),
              ),
      );
    }
    final showFooter = state.hasMore;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (showFooter &&
            notification.metrics.extentAfter < _loadMoreThreshold) {
          unawaited(context.read<CheckOutCubit>().loadMore());
        }
        return false;
      },
      child: ListView.builder(
        itemCount: state.visible.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) => index == state.visible.length
            ? _LoadMoreTile(loading: state.loadingMore)
            : _SessionTile(
                session: state.visible[index],
                plate:
                    state.plates[state.visible[index].vehicleId] ??
                    context.l10n.unknownVehicle(state.visible[index].vehicleId),
                canReprint: canReprint,
                onCharge: () => onCheckOut(
                  context,
                  state.visible[index],
                  state.plates[state.visible[index].vehicleId] ??
                      context.l10n.unknownVehicle(
                        state.visible[index].vehicleId,
                      ),
                ),
              ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.plate,
    required this.onCharge,
    required this.canReprint,
  });

  final OpenSession session;
  final String plate;
  final VoidCallback onCharge;
  final bool canReprint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final longStay = isLongStay(session.entryTime);
    return ListTile(
      isThreeLine: true,
      title: Text(plate),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sessionEntry(Formatters.dateTime(session.entryTime))),
          const SizedBox(height: 2),
          // Wrap so the elapsed time and chips never overflow when the
          // trailing actions (Cobrar + reprint) narrow the row on phones.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      elapsedLabel(l10n, session.entryTime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (longStay)
                StatusChip(
                  label: l10n.checkOutLongStay,
                  tone: StatusTone.warning,
                  icon: Icons.warning_amber_outlined,
                ),
              if (session.hasPass)
                StatusChip(
                  label: l10n.paymentMonthlyPass,
                  tone: StatusTone.success,
                  icon: Icons.card_membership,
                ),
              if (session.leftKeys)
                StatusChip(
                  label: l10n.checkInLeftKeysShort,
                  tone: StatusTone.neutral,
                  icon: Icons.key_outlined,
                ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canReprint)
            IconButton(
              tooltip: l10n.checkOutReprintTicket,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => _reprintTicket(context),
            ),
          FilledButton(
            onPressed: onCharge,
            child: Text(l10n.checkOutCharge),
          ),
        ],
      ),
    );
  }

  /// Reprints the entry ticket (with its exit QR) for a car still inside.
  Future<void> _reprintTicket(BuildContext context) {
    final data = ReceiptData(
      kind: ReceiptKind.checkIn,
      plate: plate,
      entryTime: session.entryTime,
      photoCount: session.photoCount,
    );
    return showReceipt(
      context,
      data,
      onPrint: () => showReceiptPrintSheet(context, data),
    );
  }
}

class _LoadMoreTile extends StatelessWidget {
  const _LoadMoreTile({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : OutlinedButton(
                onPressed: () => context.read<CheckOutCubit>().loadMore(),
                child: Text(context.l10n.actionLoadMore),
              ),
      ),
    );
  }
}

class _ShiftBanner extends StatelessWidget {
  const _ShiftBanner();

  @override
  Widget build(BuildContext context) {
    final ShiftCubit cubit;
    try {
      cubit = context.watch<ShiftCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    if (cubit.state.status != ShiftStatus.loaded ||
        cubit.state.current != null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.checkOutNoShift,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/shift'),
            child: Text(context.l10n.shiftOpen),
          ),
        ],
      ),
    );
  }
}

/// The method preselected before a pass is detected. A remembered monthly
/// pass is meaningless without an active pass, so it falls back to cash.
PaymentMethod _basePaymentMethod(PaymentMethod? remembered) =>
    remembered == null || remembered == PaymentMethod.monthlyPass
    ? PaymentMethod.cash
    : remembered;
