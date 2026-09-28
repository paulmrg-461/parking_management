import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/submission.dart';
import '../../categories/domain/entities/category.dart';
import '../../categories/domain/repositories/category_repository.dart';
import '../domain/commands/create_tariff_command.dart';
import '../domain/commands/update_tariff_command.dart';
import '../domain/entities/tariff.dart';
import '../domain/repositories/tariff_repository.dart';

sealed class TariffsState extends Equatable {
  const TariffsState();

  @override
  List<Object?> get props => const [];
}

final class TariffsInitial extends TariffsState {
  const TariffsInitial();
}

final class TariffsLoading extends TariffsState {
  const TariffsLoading();
}

/// Tariffs plus the categories for the create form and a precomputed
/// categoryId → name map (O(1) per row).
final class TariffsLoaded extends TariffsState {
  const TariffsLoaded({
    required this.tariffs,
    this.categories = const [],
    this.categoryNames = const {},
    this.submission = const SubmissionIdle(),
  });

  final List<Tariff> tariffs;
  final List<Category> categories;
  final Map<int, String> categoryNames;
  final Submission submission;

  String categoryNameOf(Tariff tariff) =>
      categoryNames[tariff.categoryId] ?? 'Category ${tariff.categoryId}';

  TariffsLoaded copyWith({List<Tariff>? tariffs, Submission? submission}) =>
      TariffsLoaded(
        tariffs: tariffs ?? this.tariffs,
        categories: categories,
        categoryNames: categoryNames,
        submission: submission ?? this.submission,
      );

  @override
  List<Object?> get props => [tariffs, categories, categoryNames, submission];
}

/// The list itself could not be loaded (action errors never land here).
final class TariffsFailure extends TariffsState {
  const TariffsFailure(this.message, {this.failure});

  TariffsFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

class TariffsCubit extends Cubit<TariffsState> {
  TariffsCubit(this._repository, this._categories)
    : super(const TariffsInitial());

  final TariffRepository _repository;
  final CategoryRepository _categories;

  Future<void> load() async {
    emit(const TariffsLoading());
    final categories = _loadCategories();
    try {
      final tariffs = await _repository.list();
      final loadedCategories = await categories;
      emit(
        TariffsLoaded(
          tariffs: tariffs,
          categories: loadedCategories,
          categoryNames: {
            for (final category in loadedCategories)
              if (category.id != null) category.id!: category.name,
          },
        ),
      );
    } on Failure catch (failure) {
      categories.ignore();
      emit(TariffsFailure.of(failure));
    }
  }

  Future<void> create(CreateTariffCommand command) =>
      _submit(() => _repository.create(command));

  Future<void> update(UpdateTariffCommand command) =>
      _submit(() => _repository.update(command));

  Future<void> delete(int id) => _submit(() => _repository.delete(id));

  Future<void> _submit(Future<Object?> Function() action) async {
    final current = state;
    if (current is! TariffsLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      await action();
      emit(
        current.copyWith(
          tariffs: await _repository.list(),
          submission: const SubmissionIdle(),
        ),
      );
    } on Failure catch (failure) {
      emit(current.copyWith(submission: SubmissionFailed.of(failure)));
    }
  }

  /// Best-effort: without categories rows fall back to `Category <id>`.
  Future<List<Category>> _loadCategories() async {
    try {
      return await _categories.list();
    } on Failure {
      return const [];
    }
  }
}
