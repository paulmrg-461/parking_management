import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin port over the device's connectivity status, so `SyncService` doesn't
/// depend on the `connectivity_plus` package directly.
abstract class ConnectivityService {
  Future<bool> isOnline();

  Stream<bool> get onConnectivityChanged;
}

/// `connectivity_plus` (6.x) reports connectivity as `List<ConnectivityResult>`
/// (a device can have more than one active interface). "Online" means at
/// least one reported interface is not `ConnectivityResult.none`.
class ConnectivityPlusService implements ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isConnected(results);
  }

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_isConnected);

  bool _isConnected(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
