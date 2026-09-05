import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../auth/domain/commands/create_user_command.dart';
import '../../auth/domain/commands/update_user_command.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/domain/repositories/auth_repository.dart';

sealed class UsersState extends Equatable {
  const UsersState();

  @override
  List<Object?> get props => const [];
}

class UsersInitial extends UsersState {
  const UsersInitial();
}

class UsersLoading extends UsersState {
  const UsersLoading();
}

class UsersLoaded extends UsersState {
  const UsersLoaded(this.users);

  final List<User> users;

  @override
  List<Object?> get props => [users];
}

class UsersFailure extends UsersState {
  const UsersFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class UsersCubit extends Cubit<UsersState> {
  UsersCubit(this._repository) : super(const UsersInitial());

  final AuthRepository _repository;

  Future<void> load() async {
    emit(const UsersLoading());
    try {
      emit(UsersLoaded(await _repository.listUsers()));
    } on Failure catch (failure) {
      emit(UsersFailure(failure.message));
    }
  }

  Future<void> create(CreateUserCommand command) async {
    try {
      await _repository.createUser(command);
      await load();
    } on Failure catch (failure) {
      emit(UsersFailure(failure.message));
    }
  }

  Future<void> toggleActive(User user) async {
    await _repository.updateUser(
      UpdateUserCommand(id: user.id!, isActive: !user.isActive),
    );
    await load();
  }
}
