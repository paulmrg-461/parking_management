import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../application/categories_cubit.dart';
import '../domain/entities/category.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  @override
  void initState() {
    super.initState();
    context.read<CategoriesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          return switch (state) {
            CategoriesInitial() => const SizedBox.shrink(),
            CategoriesLoading() =>
              const Center(child: CircularProgressIndicator()),
            CategoriesFailure(message: final message) =>
              Center(child: Text(message)),
            CategoriesLoaded(categories: final categories) => ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ListTile(
                    title: Text(category.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          context.read<CategoriesCubit>().delete(category),
                    ),
                    onTap: () => _showRenameDialog(context, category),
                  );
                },
              ),
          };
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    _showNameDialog(context, title: 'New category', onSave: (name) {
      context.read<CategoriesCubit>().create(name);
    });
  }

  void _showRenameDialog(BuildContext context, Category category) {
    _showNameDialog(context, title: 'Rename category', initial: category.name, onSave: (name) {
      context.read<CategoriesCubit>().rename(category, name);
    });
  }

  void _showNameDialog(
    BuildContext context, {
    required String title,
    String initial = '',
    required void Function(String) onSave,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => _NameDialog(title: title, initial: initial, onSave: onSave),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.onSave,
  });

  final String title;
  final String initial;
  final void Function(String) onSave;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(labelText: 'Name'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_controller.text.trim());
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
