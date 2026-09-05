import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/auth_session.dart';
import '../domain/repositories/auth_repository.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthInitial());

  final AuthRepository _repository;

  Future<void> restore() async {
    emit(const AuthLoading());
    final session = await _repository.restoreSession();
    emit(
      session == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(session),
    );
  }

  Future<void> login(String username, String pin) async {
    emit(const AuthLoading());
    try {
      final session = await _repository.login(username, pin);
      emit(AuthAuthenticated(session));
    } on Failure catch (failure) {
      emit(AuthFailure(failure.message));
    } on Exception {
      emit(const AuthFailure('Login failed'));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }
}
