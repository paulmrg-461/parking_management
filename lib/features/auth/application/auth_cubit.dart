import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/auth_session.dart';
import '../domain/repositories/auth_repository.dart';
import '../../../core/state/resilient_cubit.dart';

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
  const AuthUnauthenticated({this.expired = false});

  /// True when the backend rejected a request with 401 (not a user logout).
  final bool expired;

  @override
  List<Object?> get props => [expired];
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message, {this.failure});

  AuthFailure.of(Failure failure) : this(failure.message, failure: failure);

  final String message;
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure?.code];
}

class AuthCubit extends ResilientCubit<AuthState> {
  AuthCubit(this._repository, [this._onAuthenticated, this._onSessionReady])
    : super(const AuthInitial());

  final AuthRepository _repository;

  /// Lets the composition root kick the offline outbox once a token exists.
  final Future<void> Function()? _onAuthenticated;

  /// Awaited BEFORE the app sees an authenticated session: it selects the
  /// active lot, so the very first request already carries `x-lot-id` (the
  /// database rejects lot-scoped requests without it).
  final Future<void> Function()? _onSessionReady;

  Future<void> restore() async {
    emit(const AuthLoading());
    final session = await _repository.restoreSession();
    if (session != null) {
      await _sessionReady();
    }
    emit(
      session == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(session),
    );
  }

  /// A broken lot lookup must not block sign-in: requests then fail closed
  /// with `LotRequiredError` until the next refresh.
  Future<void> _sessionReady() async {
    try {
      await _onSessionReady?.call();
    } on Object {
      // Handled by the lot cubit (it keeps its failure state).
    }
  }

  Future<void> login(String username, String pin) async {
    emit(const AuthLoading());
    try {
      final session = await _repository.login(username, pin);
      await _sessionReady();
      emit(AuthAuthenticated(session));
      // The queue may have been waiting on a 401; now that there is a token,
      // replay it without waiting for another connectivity event.
      final kick = _onAuthenticated;
      if (kick != null) {
        unawaited(kick());
      }
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
    if (state is! AuthAuthenticated) {
      return;
    }
    await _repository.logout();
    emit(const AuthUnauthenticated(expired: true));
  }
}
