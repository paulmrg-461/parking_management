import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/pagination/paged_result.dart';
import '../../../core/state/submission.dart';
import '../../categories/domain/entities/category.dart';
import '../../categories/domain/repositories/category_repository.dart';
import '../domain/commands/create_vehicle_command.dart';
import '../domain/commands/update_vehicle_command.dart';
import '../domain/entities/vehicle.dart';
import '../domain/repositories/vehicle_repository.dart';

sealed class VehiclesState extends Equatable {
  const VehiclesState();

  @override
  List<Object?> get props => const [];
}

final class VehiclesInitial extends VehiclesState {
  const VehiclesInitial();
}

final class VehiclesLoading extends VehiclesState {
  const VehiclesLoading();
}

/// Loaded page(s) of vehicles plus the categories for the create form and a
/// precomputed categoryId → name map (O(1) per row).
final class VehiclesLoaded extends VehiclesState {
  const VehiclesLoaded({
    required this.vehicles,
    this.categories = const [],
    this.categoryNames = const {},
    this.total,
    this.loadingMore = false,
    this.submission = const SubmissionIdle(),
  });

  final List<Vehicle> vehicles;
  final List<Category> categories;
  final Map<int, String> categoryNames;
  final int? total;
  final bool loadingMore;
  final Submission submission;

  bool get hasMore => total != null && total! > vehicles.length;

  String categoryNameOf(Vehicle vehicle) =>
      categoryNames[vehicle.categoryId] ?? 'Category ${vehicle.categoryId}';

  VehiclesLoaded copyWith({
    List<Vehicle>? vehicles,
    int? total,
    bool? loadingMore,
    Submission? submission,
  }) => VehiclesLoaded(
    vehicles: vehicles ?? this.vehicles,
    categories: categories,
    categoryNames: categoryNames,
    total: total ?? this.total,
    loadingMore: loadingMore ?? this.loadingMore,
    submission: submission ?? this.submission,
  );

  @override
  List<Object?> get props => [
    vehicles,
    categories,
    categoryNames,
    total,
    loadingMore,
    submission,
  ];
}

/// The list itself could not be loaded (action errors never land here).
final class VehiclesFailure extends VehiclesState {
  const VehiclesFailure(this.message, {this.failure});

  VehiclesFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

class VehiclesCubit extends Cubit<VehiclesState> {
  VehiclesCubit(
    this._repository,
    this._categories, {
    this.pageSize = defaultPageSize,
  }) : super(const VehiclesInitial());

  final VehicleRepository _repository;
  final CategoryRepository _categories;
  final int pageSize;

  Future<void> load() async {
    emit(const VehiclesLoading());
    final categories = _loadCategories();
    try {
      final page = await _repository.listPage(offset: 0, limit: pageSize);
      emit(_loaded(page, await categories));
    } on Failure catch (failure) {
      categories.ignore();
      emit(VehiclesFailure.of(failure));
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! VehiclesLoaded || !current.hasMore || current.loadingMore) {
      return;
    }
    emit(current.copyWith(loadingMore: true));
    try {
      final page = await _repository.listPage(
        offset: current.vehicles.length,
        limit: pageSize,
      );
      emit(
        current.copyWith(
          vehicles: [...current.vehicles, ...page.items],
          total: page.total,
          loadingMore: false,
        ),
      );
    } on Failure catch (failure) {
      emit(
        current.copyWith(
          loadingMore: false,
          submission: SubmissionFailed.of(failure),
        ),
      );
    }
  }

  Future<void> create(CreateVehicleCommand command) =>
      _submit(() => _repository.create(command));

  Future<void> update(UpdateVehicleCommand command) =>
      _submit(() => _repository.update(command));

  Future<void> delete(int id) => _submit(() => _repository.delete(id));

  /// Keeps the list on screen while [action] runs; afterwards the first page
  /// is refetched. Failures surface as [SubmissionFailed].
  Future<void> _submit(Future<Object?> Function() action) async {
    final current = state;
    if (current is! VehiclesLoaded) {
      return;
    }
    emit(current.copyWith(submission: const SubmissionInProgress()));
    try {
      await action();
      final page = await _repository.listPage(offset: 0, limit: pageSize);
      emit(
        current.copyWith(
          vehicles: page.items,
          total: page.total,
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

  VehiclesLoaded _loaded(
    PagedResult<Vehicle> page,
    List<Category> categories,
  ) => VehiclesLoaded(
    vehicles: page.items,
    categories: categories,
    categoryNames: {
      for (final category in categories)
        if (category.id != null) category.id!: category.name,
    },
    total: page.total,
  );
}
