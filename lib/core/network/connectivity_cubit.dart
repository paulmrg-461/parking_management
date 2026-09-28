import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'connectivity_service.dart';

/// `true` while the device reports a network interface. Starts optimistic
/// (online) so the offline banner never flashes on launch.
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit(this._service) : super(true);

  final ConnectivityService _service;
  StreamSubscription<bool>? _subscription;

  Future<void> start() async {
    _subscription ??= _service.onConnectivityChanged.listen(_set);
    try {
      _set(await _service.isOnline());
    } on Object {
      // Unknown status: keep the optimistic value.
    }
  }

  void _set(bool online) {
    if (!isClosed) {
      emit(online);
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
