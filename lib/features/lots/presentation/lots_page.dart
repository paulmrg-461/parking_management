import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/submission_listener.dart';
import '../application/lots_cubit.dart';
import '../domain/entities/parking_lot.dart';
import 'create_lot_dialog.dart';
import 'lot_members_dialog.dart';

class LotsPage extends StatefulWidget {
  const LotsPage({super.key});

  @override
  State<LotsPage> createState() => _LotsPageState();
}

class _LotsPageState extends State<LotsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<LotsCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SubmissionListener<LotsCubit, LotsState>(
      submissionOf: _submissionOf,
      child: ListPageScaffold(
        title: l10n.lotsTitle,
        addTooltip: l10n.lotAdd,
        onAdd: _add,
        onRefresh: context.read<LotsCubit>().load,
        body: BlocBuilder<LotsCubit, LotsState>(
          builder: (context, state) => switch (state) {
            LotsInitial() || LotsLoading() => const SkeletonList(),
            LotsFailure(:final message) => ErrorState(
              message: message,
              onRetry: context.read<LotsCubit>().load,
            ),
            final LotsLoaded loaded => loaded.lots.isEmpty
                ? Center(child: Text(l10n.lotsEmpty))
                : ListView.builder(
                    itemCount: loaded.lots.length,
                    itemBuilder: (context, index) =>
                        _LotTile(lot: loaded.lots[index]),
                  ),
          },
        ),
      ),
    );
  }

  static Submission? _submissionOf(LotsState state) =>
      state is LotsLoaded ? state.submission : null;

  Future<void> _add() async {
    final cubit = context.read<LotsCubit>();
    await showDialog<void>(
      context: context,
      builder: (_) => CreateLotDialog(
        onCreate: (draft) => cubit.create(
          code: draft.code,
          name: draft.name,
          address: draft.address,
        ),
      ),
    );
  }
}

class _LotTile extends StatelessWidget {
  const _LotTile({required this.lot});

  final ParkingLot lot;

  Future<void> _openMembers(BuildContext context) async {
    final cubit = context.read<LotsCubit>();
    await showDialog<void>(
      context: context,
      builder: (_) => LotMembersDialog(
        lotName: lot.name,
        loadMembers: () => cubit.members(lot.id),
        onSetRole: (member, role) =>
            cubit.setMember(member.userId, lot.id, role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
      child: ListTile(
        title: Text(lot.name),
        subtitle: Text(
          [
            lot.code,
            if (lot.address.isNotEmpty) lot.address,
            l10n.lotMembers(lot.members),
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.lotMembersTitle(lot.name),
              icon: const Icon(Icons.group_outlined),
              onPressed: () => _openMembers(context),
            ),
            Switch(
              value: lot.active,
              onChanged: (value) => context.read<LotsCubit>().setActiveFlag(
                lot,
                value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
