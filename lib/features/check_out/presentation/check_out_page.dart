import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/receipt_card.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../auth/application/auth_cubit.dart';
import '../../auth/domain/entities/user.dart';
import '../../home/application/dashboard_cubit.dart';
import '../../receipt_printing/presentation/receipt_print_sheet.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../application/check_out_cubit.dart';
import '../domain/entities/check_out_receipt.dart';
import '../../../core/receipt/payment_method.dart';
import '../domain/entities/open_session.dart';
import 'payment_method_dialog.dart';

/// Lists currently open parking sessions (plates resolved by the cubit),
/// lets an operator search by plate (debounced in the cubit) and close one
/// out, showing a receipt on success. Long lists page in on scroll.
class CheckOutPage extends StatefulWidget {
  const CheckOutPage({super.key});

  @override
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<CheckOutCubit>().loadOpenSessions());
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
              child: TextField(
                decoration: InputDecoration(
                  labelText: context.l10n.searchPlate,
                  prefixIcon: const Icon(Icons.search),
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: context.read<CheckOutCubit>().search,
              ),
            ),
            const Expanded(child: _SessionsList()),
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
        unawaited(context.read<DashboardCubit>().load());
        unawaited(_showReceipt(context, result));
      case SubmissionFailed(:final message, :final failure):
        showErrorSnack(context, context.l10n.errorText(message, failure));
      default:
        break;
    }
  }

  Future<void> _showReceipt(BuildContext context, CheckOutReceipt receipt) {
    final data = _receiptData(receipt);
    return showReceiptSummary(
      context,
      data,
      onPrint: () => showReceiptPrintSheet(context, data),
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
  const _SessionsList();

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
        CheckOutInitial() ||
        CheckOutLoading() => const Center(child: CircularProgressIndicator()),
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
      return Center(child: Text(context.l10n.openSessionsEmpty));
    }
    final showFooter = state.hasMore && state.query.isEmpty;
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
                    context.l10n.unknownVehicle(
                      state.visible[index].vehicleId,
                    ),
              ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.plate});

  final OpenSession session;
  final String plate;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(plate),
      subtitle: Text(
        context.l10n.sessionEntry(Formatters.dateTime(session.entryTime)),
      ),
      trailing: FilledButton(
        onPressed: () => _confirmCheckOut(context),
        child: Text(context.l10n.checkOutCharge),
      ),
    );
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

  Future<void> _confirmCheckOut(BuildContext context) async {
    final cubit = context.read<CheckOutCubit>();
    final canDiscount = _canDiscount(context);
    final choice = await showCheckoutDialog(
      context,
      plate: plate,
      canDiscount: canDiscount,
    );
    if (choice == null) {
      return;
    }
    await cubit.checkOut(
      session.id,
      paymentMethod: choice.method.wire,
      discountAmount: choice.discountAmount,
      discountReason: choice.discountReason,
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
