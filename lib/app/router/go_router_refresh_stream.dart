import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a [Stream] (e.g. `AuthCubit.stream`) into a [Listenable] for
/// `GoRouter.refreshListenable`, so redirects re-run on every auth change.
/// Safe to dispose: the subscription is cancelled and late events ignored.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen(
      (_) => notifyListeners(),
      onError: (Object _) {},
    );
  }

  late final StreamSubscription<dynamic> _subscription;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
