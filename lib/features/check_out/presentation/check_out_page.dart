import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/submission.dart';
import '../../../core/widgets/receipt_card.dart';
import '../../../core/widgets/submission_feedback.dart';
import '../../../core/widgets/sync_badge.dart';
import '../application/check_out_cubit.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/entities/open_session.dart';

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
        title: const Text('Check-out'),
        actions: const [SyncBadge()],
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
                decoration: const InputDecoration(
                  labelText: 'Search by plate',
                  prefixIcon: Icon(Icons.search),
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
        unawaited(_showReceipt(context, result));
      case SubmissionFailed(:final message):
        showErrorSnack(context, message);
      default:
        break;
    }
  }

  Future<void> _showReceipt(BuildContext context, CheckOutReceipt receipt) {
    return showReceiptSummary(context, _receiptData(receipt));
  }

  ReceiptData _receiptData(CheckOutReceipt receipt) => ReceiptData(
    kind: ReceiptKind.checkOut,
    plate: receipt.plate,
    entryTime: receipt.entryTime,
    exitTime: receipt.exitTime,
    amountCharged: receipt.amountCharged,
    ticketNumber: receipt.ticketNumber,
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
        CheckOutFailure(:final message) => Center(child: Text(message)),
        final CheckOutLoaded loaded => _buildList(context, loaded),
      },
    );
  }

  Widget _buildList(BuildContext context, CheckOutLoaded state) {
    if (state.visible.isEmpty) {
      return const Center(child: Text('No open sessions'));
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
                plate: state.plateOf(state.visible[index]),
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
      subtitle: Text('Entry: ${session.entryTime.toLocal()}'),
      trailing: FilledButton(
        onPressed: () => _confirmCheckOut(context),
        child: const Text('Check out'),
      ),
    );
  }

  Future<void> _confirmCheckOut(BuildContext context) async {
    final cubit = context.read<CheckOutCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check out'),
        content: Text('Check out vehicle $plate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await cubit.checkOut(session.id);
    }
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
                child: const Text('Load more'),
              ),
      ),
    );
  }
}
