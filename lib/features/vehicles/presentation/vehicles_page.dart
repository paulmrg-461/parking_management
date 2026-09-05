import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../categories/application/categories_cubit.dart';
import '../../categories/domain/entities/category.dart';
import '../application/vehicles_cubit.dart';
import '../domain/commands/create_vehicle_command.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  @override
  void initState() {
    super.initState();
    context.read<VehiclesCubit>().load();
    context.read<CategoriesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<VehiclesCubit, VehiclesState>(
        builder: (context, state) {
          return switch (state) {
            VehiclesInitial() => const SizedBox.shrink(),
            VehiclesLoading() =>
              const Center(child: CircularProgressIndicator()),
            VehiclesFailure(message: final message) => Center(child: Text(message)),
            VehiclesLoaded(vehicles: final vehicles) => BlocBuilder<CategoriesCubit, CategoriesState>(
                builder: (context, categoriesState) {
                  final categories = categoriesState is CategoriesLoaded
                      ? categoriesState.categories
                      : const <Category>[];
                  return ListView.builder(
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      return ListTile(
                        title: Text(vehicle.plate),
                        subtitle: Text(
                          '${_nameOf(categories, vehicle.categoryId)}'
                          '${vehicle.brand != null ? ' · ${vehicle.brand}' : ''}'
                          '${vehicle.color != null ? ' · ${vehicle.color}' : ''}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              context.read<VehiclesCubit>().delete(vehicle.id!),
                        ),
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

  String _nameOf(List<Category> categories, int categoryId) {
    for (final category in categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    return 'Category $categoryId';
  }

  void _showCreateDialog(BuildContext context) {
    final categories = context.read<CategoriesCubit>().state;
    final options = categories is CategoriesLoaded ? categories.categories : const <Category>[];
    showDialog<void>(
      context: context,
      builder: (context) => _CreateVehicleDialog(categories: options),
    );
  }
}

class _CreateVehicleDialog extends StatefulWidget {
  const _CreateVehicleDialog({required this.categories});

  final List<Category> categories;

  @override
  State<_CreateVehicleDialog> createState() => _CreateVehicleDialogState();
}

class _CreateVehicleDialogState extends State<_CreateVehicleDialog> {
  final _plateController = TextEditingController();
  final _colorController = TextEditingController();
  final _brandController = TextEditingController();
  int? _categoryId;

  @override
  void dispose() {
    _plateController.dispose();
    _colorController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final categoryId = _categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    if (categoryId == null) {
      return;
    }
    context.read<VehiclesCubit>().create(
          CreateVehicleCommand(
            plate: _plateController.text.trim(),
            categoryId: categoryId,
            color: _colorController.text.trim(),
            brand: _brandController.text.trim(),
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New vehicle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _plateController,
            decoration: const InputDecoration(labelText: 'Plate'),
          ),
          DropdownButtonFormField<int>(
            initialValue: _categoryId,
            items: widget.categories
                .map((category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _categoryId = value),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          TextField(
            controller: _brandController,
            decoration: const InputDecoration(labelText: 'Brand'),
          ),
          TextField(
            controller: _colorController,
            decoration: const InputDecoration(labelText: 'Color'),
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
