import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/submission.dart';
import '../domain/entities/category.dart';
import '../domain/repositories/category_repository.dart';

sealed class CategoriesState extends Equatable {
  const CategoriesState();

  @override
  List<Object?> get props => const [];
}

final class CategoriesInitial extends CategoriesState {
  const CategoriesInitial();
}

final class CategoriesLoading extends CategoriesState {
  const CategoriesLoading();
}

final class CategoriesLoaded extends CategoriesState {
  const CategoriesLoaded(
    this.categories, {
    this.submission = const SubmissionIdle(),
  });

  final List<Category> categories;
  final Submission submission;

  @override
  List<Object?> get props => [categories, submission];
}

/// The list itself could not be loaded (action errors never land here).
final class CategoriesFailure extends CategoriesState {
  const CategoriesFailure(this.message, {this.failure});

  CategoriesFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(this._repository) : super(const CategoriesInitial());

  final CategoryRepository _repository;

  Future<void> load() async {
    emit(const CategoriesLoading());
    try {
      emit(CategoriesLoaded(await _repository.list()));
    } on Failure catch (failure) {
      emit(CategoriesFailure.of(failure));
    }
  }

  Future<void> create(String name) => _submit(() => _repository.create(name));

  Future<void> rename(Category category, String name) async {
    final id = category.id;
    if (id != null) {
      await _submit(() => _repository.update(id, name));
    }
  }

  Future<void> delete(Category category) async {
    final id = category.id;
    if (id != null) {
      await _submit(() => _repository.delete(id));
    }
  }

  Future<void> _submit(Future<Object?> Function() action) async {
    final current = state;
    final categories = current is CategoriesLoaded
        ? current.categories
        : const <Category>[];
    emit(
      CategoriesLoaded(categories, submission: const SubmissionInProgress()),
    );
    try {
      await action();
      emit(CategoriesLoaded(await _repository.list()));
    } on Failure catch (failure) {
      emit(
        CategoriesLoaded(
          categories,
          submission: SubmissionFailed.of(failure),
        ),
      );
    }
  }
}
