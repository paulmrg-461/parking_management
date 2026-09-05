import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../vehicles/application/vehicles_cubit.dart';
import '../../vehicles/domain/entities/vehicle.dart';
import '../application/monthly_passes_cubit.dart';
import '../domain/commands/create_monthly_pass_command.dart';
import '../domain/commands/update_monthly_pass_command.dart';
import '../domain/entities/monthly_pass.dart';

/// Admin-only reference-data CRUD screen for monthly passes. Resolves each
/// pass's `vehicle_id` to its plate via [VehiclesCubit], the same join style
/// used by the tariffs/check-out features.
class MonthlyPassesPage extends StatefulWidget {
  const MonthlyPassesPage({super.key});

  @override
  State<MonthlyPassesPage> createState() => _MonthlyPassesPageState();
}

class _MonthlyPassesPageState extends State<MonthlyPassesPage> {
  @override
  void initState() {
    super.initState();
    context.read<MonthlyPassesCubit>().load();
    context.read<VehiclesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly passes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<MonthlyPassesCubit, MonthlyPassesState>(
        builder: (context, state) {
          return switch (state) {
            MonthlyPassesInitial() => const SizedBox.shrink(),
            MonthlyPassesLoading() =>
              const Center(child: CircularProgressIndicator()),
            MonthlyPassesFailure(message: final message) =>
              Center(child: Text(message)),
            MonthlyPassesLoaded(monthlyPasses: final monthlyPasses) =>
              BlocBuilder<VehiclesCubit, VehiclesState>(
                builder: (context, vehiclesState) {
                  final vehicles = vehiclesState is VehiclesLoaded
                      ? vehiclesState.vehicles
                      : const <Vehicle>[];
                  return ListView.builder(
                    itemCount: monthlyPasses.length,
                    itemBuilder: (context, index) {
                      final monthlyPass = monthlyPasses[index];
                      return _MonthlyPassTile(
                        monthlyPass: monthlyPass,
                        plate: _plateOf(vehicles, monthlyPass.vehicleId),
                        vehicles: vehicles,
                      );
                    },
                  );
                },
              ),
          };
        },
      ),
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

  void _showCreateDialog(BuildContext context) {
    final vehiclesState = context.read<VehiclesCubit>().state;
    final vehicles =
        vehiclesState is VehiclesLoaded ? vehiclesState.vehicles : const <Vehicle>[];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<MonthlyPassesCubit>(),
        child: _CreateMonthlyPassDialog(vehicles: vehicles),
      ),
    );
  }
}

class _MonthlyPassTile extends StatelessWidget {
  const _MonthlyPassTile({
    required this.monthlyPass,
    required this.plate,
    required this.vehicles,
  });

  final MonthlyPass monthlyPass;
  final String plate;
  final List<Vehicle> vehicles;

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(plate),
      subtitle: Text(
        '${_formatDate(monthlyPass.startDate)} - '
        '${_formatDate(monthlyPass.endDate)} · ${monthlyPass.amount} COP',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: monthlyPass.active,
            onChanged: (value) => context.read<MonthlyPassesCubit>().update(
                  UpdateMonthlyPassCommand(id: monthlyPass.id!, active: value),
                ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => BlocProvider.value(
                value: context.read<MonthlyPassesCubit>(),
                child: _EditMonthlyPassDialog(
                  monthlyPass: monthlyPass,
                  vehicles: vehicles,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<MonthlyPassesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete monthly pass'),
        content: Text('Delete the monthly pass for $plate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await cubit.delete(monthlyPass.id!);
    }
  }
}

class _CreateMonthlyPassDialog extends StatefulWidget {
  const _CreateMonthlyPassDialog({required this.vehicles});

  final List<Vehicle> vehicles;

  @override
  State<_CreateMonthlyPassDialog> createState() =>
      _CreateMonthlyPassDialogState();
}

class _CreateMonthlyPassDialogState extends State<_CreateMonthlyPassDialog> {
  final _amountController = TextEditingController();
  int? _vehicleId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _submit(BuildContext context) {
    final vehicleId = _vehicleId ??
        (widget.vehicles.isNotEmpty ? widget.vehicles.first.id : null);
    final startDate = _startDate;
    final endDate = _endDate;
    if (vehicleId == null || startDate == null || endDate == null) {
      return;
    }
    context.read<MonthlyPassesCubit>().create(
          CreateMonthlyPassCommand(
            vehicleId: vehicleId,
            startDate: startDate,
            endDate: endDate,
            amount: int.tryParse(_amountController.text) ?? 0,
          ),
        );
    Navigator.of(context).pop();
  }

  String _label(DateTime? date) => date == null
      ? 'Select date'
      : '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New monthly pass'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _vehicleId,
            items: widget.vehicles
                .map((vehicle) => DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(vehicle.plate),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _vehicleId = value),
            decoration: const InputDecoration(labelText: 'Vehicle'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start date'),
            subtitle: Text(_label(_startDate)),
            onTap: () => _pickStartDate(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End date'),
            subtitle: Text(_label(_endDate)),
            onTap: () => _pickEndDate(context),
          ),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount (COP)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EditMonthlyPassDialog extends StatefulWidget {
  const _EditMonthlyPassDialog({
    required this.monthlyPass,
    required this.vehicles,
  });

  final MonthlyPass monthlyPass;
  final List<Vehicle> vehicles;

  @override
  State<_EditMonthlyPassDialog> createState() =>
      _EditMonthlyPassDialogState();
}

class _EditMonthlyPassDialogState extends State<_EditMonthlyPassDialog> {
  late final TextEditingController _amountController;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.monthlyPass.amount.toString());
    _startDate = widget.monthlyPass.startDate;
    _endDate = widget.monthlyPass.endDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _submit(BuildContext context) {
    context.read<MonthlyPassesCubit>().update(
          UpdateMonthlyPassCommand(
            id: widget.monthlyPass.id!,
            startDate: _startDate,
            endDate: _endDate,
            amount: int.tryParse(_amountController.text) ?? widget.monthlyPass.amount,
          ),
        );
    Navigator.of(context).pop();
  }

  String _label(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit monthly pass'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start date'),
            subtitle: Text(_label(_startDate)),
            onTap: () => _pickStartDate(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End date'),
            subtitle: Text(_label(_endDate)),
            onTap: () => _pickEndDate(context),
          ),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount (COP)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
