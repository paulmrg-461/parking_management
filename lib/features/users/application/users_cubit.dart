import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/state/submission.dart';
import '../../auth/domain/entities/user.dart';
import '../domain/commands/create_user_command.dart';
import '../domain/commands/update_user_command.dart';
import '../domain/repositories/user_repository.dart';

sealed class UsersState extends Equatable {
  const UsersState();

  @override
  List<Object?> get props => const [];
}

final class UsersInitial extends UsersState {
  const UsersInitial();
}

final class UsersLoading extends UsersState {
  const UsersLoading();
}

final class UsersLoaded extends UsersState {
  const UsersLoaded(this.users, {this.submission = const SubmissionIdle()});

  final List<User> users;
  final Submission submission;

  UsersLoaded withSubmission(Submission submission) =>
      UsersLoaded(users, submission: submission);

  @override
  List<Object?> get props => [users, submission];
}

/// The list itself could not be loaded (action errors never land here).
final class UsersFailure extends UsersState {
  const UsersFailure(this.message, {this.failure});

  UsersFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

class UsersCubit extends Cubit<UsersState> {
  UsersCubit(this._repository) : super(const UsersInitial());

  final UserRepository _repository;

  Future<void> load() async {
    emit(const UsersLoading());
    try {
      emit(UsersLoaded(await _repository.list()));
    } on Failure catch (failure) {
      emit(UsersFailure.of(failure));
    }
  }

  Future<void> create(CreateUserCommand command) =>
      _submit(() => _repository.create(command));

  Future<void> toggleActive(User user) async {
    final id = user.id;
    if (id == null) {
      return;
    }
    await _submit(
      () => _repository.update(
        UpdateUserCommand(id: id, isActive: !user.isActive),
      ),
    );
  }

  /// Keeps the current list on screen while [action] runs; a failure is
  /// reported as [SubmissionFailed] instead of replacing the list.
  Future<void> _submit(Future<Object?> Function() action) async {
    final current = state;
    final users = current is UsersLoaded ? current.users : const <User>[];
    emit(UsersLoaded(users, submission: const SubmissionInProgress()));
    try {
      await action();
      emit(UsersLoaded(await _repository.list()));
    } on Failure catch (failure) {
      emit(UsersLoaded(users, submission: SubmissionFailed.of(failure)));
    }
  }
}
