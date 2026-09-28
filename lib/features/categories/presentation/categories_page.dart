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
import '../../../core/widgets/submission_listener.dart';
import '../application/categories_cubit.dart';
import '../domain/entities/category.dart';
import 'name_dialog.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<CategoriesCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CategoriesCubit>();
    return ListPageScaffold(
      title: context.l10n.categoriesTitle,
      addTooltip: context.l10n.categoryAddTooltip,
      onAdd: () => _showCreateDialog(context),
      onRefresh: cubit.load,
      body: SubmissionListener<CategoriesCubit, CategoriesState>(
        submissionOf: _submissionOf,
        child: BlocBuilder<CategoriesCubit, CategoriesState>(
          buildWhen: (previous, current) =>
              previous is! CategoriesLoaded ||
              current is! CategoriesLoaded ||
              previous.categories != current.categories,
          builder: (context, state) => AsyncView<List<Category>>(
            status: _status(context, state),
            builder: (categories) => _CategoryList(categories: categories),
          ),
        ),
      ),
    );
  }

  AsyncStatus<List<Category>> _status(
    BuildContext context,
    CategoriesState state,
  ) => switch (state) {
    CategoriesInitial() || CategoriesLoading() => const AsyncLoading(),
    CategoriesFailure(:final message, :final failure) => AsyncFailed(
      context.l10n.errorText(message, failure),
      context.read<CategoriesCubit>().load,
    ),
    CategoriesLoaded(:final categories) when categories.isEmpty => AsyncEmpty(
      context.l10n.categoriesEmpty,
      icon: Icons.category_outlined,
    ),
    CategoriesLoaded(:final categories) => AsyncReady(categories),
  };

  static Submission? _submissionOf(CategoriesState state) =>
      state is CategoriesLoaded ? state.submission : null;

  void _showCreateDialog(BuildContext context) {
    final cubit = context.read<CategoriesCubit>();
    unawaited(
      NameDialog.show(
        context,
        NameDialog(title: context.l10n.categoryNew, onSave: cubit.create),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.only(bottom: Space.xxl * 2),
    itemCount: categories.length,
    itemBuilder: (context, index) => _CategoryTile(category: categories[index]),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.category_outlined),
    title: Text(category.name),
    trailing: AppIconButton(
      icon: Icons.delete_outline,
      tooltip: context.l10n.categoryDeleteTooltip(category.name),
      onPressed: () => _confirmDelete(context),
    ),
    onTap: () => _rename(context),
  );

  void _rename(BuildContext context) {
    final cubit = context.read<CategoriesCubit>();
    unawaited(
      NameDialog.show(
        context,
        NameDialog(
          title: context.l10n.categoryRename,
          initial: category.name,
          onSave: (name) => cubit.rename(category, name),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<CategoriesCubit>();
    final l10n = context.l10n;
    final confirmed = await ConfirmDialog.show(
      context,
      ConfirmDialog(
        title: l10n.categoryDeleteTitle,
        body: l10n.categoryDeleteBody(category.name),
        confirmLabel: l10n.actionDelete,
        destructive: true,
      ),
    );
    if (confirmed) {
      await cubit.delete(category);
    }
  }
}
