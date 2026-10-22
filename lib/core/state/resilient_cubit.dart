import 'package:flutter_bloc/flutter_bloc.dart';

/// A [Cubit] that silently ignores late state emissions instead of throwing
/// `StateError: Cannot emit new states after calling close`.
///
/// Cubits live exactly as long as their page: tapping back while a list is
/// loading leaves an in-flight future that resolves after `close()`. Making
/// every call site remember `if (!isClosed)` is error-prone, so the guard
/// belongs in one place.
abstract class ResilientCubit<State> extends Cubit<State> {
  ResilientCubit(super.initialState);

  @override
  void emit(State state) {
    if (isClosed) {
      return;
    }
    super.emit(state);
  }
}
