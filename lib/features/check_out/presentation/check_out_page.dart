import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/cop_formatter.dart';
import '../../vehicles/application/vehicles_cubit.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../application/check_out_cubit.dart';
import '../domain/entities/check_out_receipt.dart';
import '../domain/entities/open_session.dart';

/// Lists currently open parking sessions (resolving each session's
/// `vehicle_id` to its plate via [VehiclesCubit], the same join style used
/// by the vehicles feature) and lets an operator search by plate and close
/// one out, showing a receipt on success.
class CheckOutPage extends StatefulWidget {
  const CheckOutPage({super.key});

  @override
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<CheckOutCubit>().loadOpenSessions();
    context.read<VehiclesCubit>().load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmCheckOut(
    BuildContext context,
    OpenSession session,
    String plate,
  ) async {
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
    if (confirmed == true && context.mounted) {
      context.read<CheckOutCubit>().checkOut(session.id);
    }
  }

  Future<void> _showReceipt(BuildContext context, CheckOutReceipt receipt) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Check-out complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _receiptLines(receipt),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// A queued (`pendingSync`) check-out has no amount/ticket yet — this
  /// project never shows a client-computed fare guess, so the dialog shows a
  /// pending notice instead of the numeric receipt.
  List<Widget> _receiptLines(CheckOutReceipt receipt) {
    if (receipt.pendingSync) {
      return const [Text('Queued — amount pending sync')];
    }
    return [
      Text('Plate: ${receipt.plate}'),
      Text('Entry: ${receipt.entryTime}'),
      Text('Exit: ${receipt.exitTime}'),
      Text('Amount: ${CopFormatter.format(receipt.amountCharged!)}'),
      Text('Ticket: ${receipt.ticketNumber}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-out')),
      body: BlocConsumer<CheckOutCubit, CheckOutState>(
        listener: (context, state) {
          if (state is CheckOutSuccess) {
            _showReceipt(context, state.receipt);
          }
        },
        builder: (context, state) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search by plate',
                  prefixIcon: Icon(Icons.search),
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(child: _buildBody(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CheckOutState state) {
    return switch (state) {
      CheckOutInitial() ||
      CheckOutLoading() ||
      CheckOutProcessing() ||
      CheckOutSuccess() =>
        const Center(child: CircularProgressIndicator()),
      CheckOutFailure(message: final message) => Center(child: Text(message)),
      CheckOutLoaded(sessions: final sessions) =>
        BlocBuilder<VehiclesCubit, VehiclesState>(
          builder: (context, vehiclesState) {
            final vehicles = vehiclesState is VehiclesLoaded
                ? vehiclesState.vehicles
                : const <Vehicle>[];
            return _buildSessionsList(context, sessions, vehicles);
          },
        ),
    };
  }

  Widget _buildSessionsList(
    BuildContext context,
    List<OpenSession> sessions,
    List<Vehicle> vehicles,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final entries = [
      for (final session in sessions)
        (session: session, plate: _plateOf(vehicles, session.vehicleId)),
    ].where((entry) => query.isEmpty || entry.plate.toLowerCase().contains(query)).toList();

    if (entries.isEmpty) {
      return const Center(child: Text('No open sessions'));
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          title: Text(entry.plate),
          subtitle: Text('Entry: ${entry.session.entryTime}'),
          trailing: FilledButton(
            onPressed: () => _confirmCheckOut(context, entry.session, entry.plate),
            child: const Text('Check out'),
          ),
        );
      },
    );
  }

  String _plateOf(List<Vehicle> vehicles, int vehicleId) {
    for (final vehicle in vehicles) {
      if (vehicle.id == vehicleId) {
        return vehicle.plate;
      }
    }
    return 'Vehicle $vehicleId';
  }
}
