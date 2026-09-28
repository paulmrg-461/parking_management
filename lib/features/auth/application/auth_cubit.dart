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
  const AuthFailure(this.message, {this.failure});

  AuthFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
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
      emit(AuthFailure.of(failure));
    } on Exception {
      emit(const AuthFailure('Login failed'));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }

  /// Called by the network layer on a 401 for an authenticated request.
  /// Ignored unless a user is signed in (avoids loops on the login screen).
  Future<void> sessionExpired() async {
    if (state is AuthAuthenticated) {
      await logout();
    }
  }
}
