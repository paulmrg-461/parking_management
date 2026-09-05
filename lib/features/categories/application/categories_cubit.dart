import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/category.dart';
import '../domain/repositories/category_repository.dart';

sealed class CategoriesState extends Equatable {
  const CategoriesState();

  @override
  List<Object?> get props => const [];
}

class CategoriesInitial extends CategoriesState {
  const CategoriesInitial();
}

class CategoriesLoading extends CategoriesState {
  const CategoriesLoading();
}

class CategoriesLoaded extends CategoriesState {
  const CategoriesLoaded(this.categories);

  final List<Category> categories;

  @override
  List<Object?> get props => [categories];
}

class CategoriesFailure extends CategoriesState {
  const CategoriesFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(this._repository) : super(const CategoriesInitial());

  final CategoryRepository _repository;

  Future<void> load() async {
    emit(const CategoriesLoading());
    try {
      emit(CategoriesLoaded(await _repository.list()));
    } on Failure catch (failure) {
      emit(CategoriesFailure(failure.message));
    }
  }

  Future<void> create(String name) async {
    await _run(() => _repository.create(name));
  }

  Future<void> rename(Category category, String name) async {
    if (category.id == null) {
      return;
    }
    await _run(() => _repository.update(category.id!, name));
  }

  Future<void> delete(Category category) async {
    if (category.id == null) {
      return;
    }
    await _run(() => _repository.delete(category.id!));
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
      await load();
    } on Failure catch (failure) {
      emit(CategoriesFailure(failure.message));
    }
  }
}
