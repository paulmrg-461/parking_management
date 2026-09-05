import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../categories/application/categories_cubit.dart';
import '../../categories/domain/entities/category.dart';
import '../application/tariffs_cubit.dart';
import '../domain/commands/create_tariff_command.dart';
import '../domain/commands/update_tariff_command.dart';
import '../domain/entities/tariff.dart';

class TariffsPage extends StatefulWidget {
  const TariffsPage({super.key});

  @override
  State<TariffsPage> createState() => _TariffsPageState();
}

class _TariffsPageState extends State<TariffsPage> {
  @override
  void initState() {
    super.initState();
    context.read<TariffsCubit>().load();
    context.read<CategoriesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tariffs')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<TariffsCubit, TariffsState>(
        builder: (context, state) {
          return switch (state) {
            TariffsInitial() => const SizedBox.shrink(),
            TariffsLoading() =>
              const Center(child: CircularProgressIndicator()),
            TariffsFailure(message: final message) => Center(child: Text(message)),
            TariffsLoaded(tariffs: final tariffs) => BlocBuilder<CategoriesCubit, CategoriesState>(
                builder: (context, categoriesState) {
                  final categories = categoriesState is CategoriesLoaded
                      ? categoriesState.categories
                      : const <Category>[];
                  return ListView.builder(
                    itemCount: tariffs.length,
                    itemBuilder: (context, index) {
                      final tariff = tariffs[index];
                      return _TariffTile(
                        tariff: tariff,
                        categoryName: _nameOf(categories, tariff.categoryId),
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
      builder: (context) => _CreateTariffDialog(categories: options),
    );
  }
}

class _TariffTile extends StatelessWidget {
  const _TariffTile({required this.tariff, required this.categoryName});

  final Tariff tariff;
  final String categoryName;

  String get _window => tariff.type == TariffType.nightly
      ? ' (${tariff.startTime}-${tariff.endTime})'
      : '';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('$categoryName · ${tariff.type.name}'),
      subtitle: Text('${tariff.amount} COP$_window'),
      trailing: Switch(
        value: tariff.active,
        onChanged: (_) => context.read<TariffsCubit>().update(
              UpdateTariffCommand(id: tariff.id!, active: !tariff.active),
            ),
      ),
    );
  }
}

class _CreateTariffDialog extends StatefulWidget {
  const _CreateTariffDialog({required this.categories});

  final List<Category> categories;

  @override
  State<_CreateTariffDialog> createState() => _CreateTariffDialogState();
}

class _CreateTariffDialogState extends State<_CreateTariffDialog> {
  final _amountController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  int? _categoryId;
  TariffType _type = TariffType.hourly;

  @override
  void dispose() {
    _amountController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final categoryId = _categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    if (categoryId == null) {
      return;
    }
    final command = CreateTariffCommand(
      categoryId: categoryId,
      type: _type,
      amount: int.tryParse(_amountController.text) ?? 0,
      startTime: _type == TariffType.nightly ? _startController.text : null,
      endTime: _type == TariffType.nightly ? _endController.text : null,
    );
    context.read<TariffsCubit>().create(command);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New tariff'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          DropdownButtonFormField<TariffType>(
            initialValue: _type,
            items: TariffType.values
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _type = value ?? _type),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount (COP)'),
          ),
          if (_type == TariffType.nightly) ...[
            TextField(
              controller: _startController,
              decoration: const InputDecoration(labelText: 'Start (HH:MM)'),
            ),
            TextField(
              controller: _endController,
              decoration: const InputDecoration(labelText: 'End (HH:MM)'),
            ),
          ],
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
