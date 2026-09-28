import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/state/submission.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/list_page_scaffold.dart';
import '../../../core/widgets/load_more_tile.dart';
import '../../../core/widgets/plate_text.dart';
import '../../../core/widgets/submission_listener.dart';
import '../../categories/domain/entities/category.dart';
import '../application/vehicles_cubit.dart';
import '../domain/entities/vehicle.dart';
import 'create_vehicle_dialog.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<VehiclesCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    return ListPageScaffold(
      title: context.l10n.vehiclesTitle,
      addTooltip: context.l10n.vehicleAddTooltip,
      onAdd: () => _showCreateDialog(context),
      onRefresh: context.read<VehiclesCubit>().load,
      body: SubmissionListener<VehiclesCubit, VehiclesState>(
        submissionOf: _submissionOf,
        child: BlocBuilder<VehiclesCubit, VehiclesState>(
          buildWhen: (previous, current) =>
              previous is! VehiclesLoaded ||
              current is! VehiclesLoaded ||
              previous.vehicles != current.vehicles ||
              previous.categoryNames != current.categoryNames ||
              previous.hasMore != current.hasMore ||
              previous.loadingMore != current.loadingMore,
          builder: (context, state) => AsyncView<VehiclesLoaded>(
            status: _status(context, state),
            builder: (loaded) => _VehicleList(state: loaded),
          ),
        ),
      ),
    );
  }

  AsyncStatus<VehiclesLoaded> _status(
    BuildContext context,
    VehiclesState state,
  ) => switch (state) {
    VehiclesInitial() || VehiclesLoading() => const AsyncLoading(),
    VehiclesFailure(:final message, :final failure) => AsyncFailed(
      context.l10n.errorText(message, failure),
      context.read<VehiclesCubit>().load,
    ),
    VehiclesLoaded(:final vehicles) when vehicles.isEmpty => AsyncEmpty(
      context.l10n.vehiclesEmpty,
      icon: Icons.directions_car_outlined,
    ),
    final VehiclesLoaded loaded => AsyncReady(loaded),
  };

  static Submission? _submissionOf(VehiclesState state) =>
      state is VehiclesLoaded ? state.submission : null;

  void _showCreateDialog(BuildContext context) {
    final cubit = context.read<VehiclesCubit>();
    final state = cubit.state;
    final options = state is VehiclesLoaded
        ? state.categories
        : const <Category>[];
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) =>
            CreateVehicleDialog(categories: options, onCreate: cubit.create),
      ),
    );
  }
}

class _VehicleList extends StatelessWidget {
  const _VehicleList({required this.state});

  final VehiclesLoaded state;

  @override
  Widget build(BuildContext context) {
    final vehicles = state.vehicles;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: Space.xxl * 2),
      itemCount: vehicles.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == vehicles.length) {
          return LoadMoreTile(
            loading: state.loadingMore,
            onLoad: context.read<VehiclesCubit>().loadMore,
          );
        }
        return _VehicleTile(
          vehicle: vehicles[index],
          categoryName: _categoryName(context, vehicles[index]),
        );
      },
    );
  }

  String _categoryName(BuildContext context, Vehicle vehicle) =>
      state.categoryNames[vehicle.categoryId] ??
      context.l10n.categoryFallback(vehicle.categoryId);
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({required this.vehicle, required this.categoryName});

  final Vehicle vehicle;
  final String categoryName;

  String get _subtitle => [
    categoryName,
    ?vehicle.brand,
    ?vehicle.color,
  ].where((part) => part.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.directions_car_outlined),
      title: PlateText(vehicle.plate),
      subtitle: Text(_subtitle),
      trailing: AppIconButton(
        icon: Icons.delete_outline,
        tooltip: context.l10n.vehicleDeleteTooltip(vehicle.plate),
        onPressed: vehicle.id == null ? null : () => _confirmDelete(context),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<VehiclesCubit>();
    final l10n = context.l10n;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.vehicleDeleteTitle,
        body: l10n.vehicleDeleteBody(vehicle.plate),
        confirmLabel: l10n.actionDelete,
        destructive: true,
      ),
    );
    if (confirmed) {
      await cubit.delete(vehicle.id!);
    }
  }
}
