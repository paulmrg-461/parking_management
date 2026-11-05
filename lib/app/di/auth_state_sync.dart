import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/infrastructure/auth_local_data_source.dart';

/// Bridges GoTrue auth events to the app session.
///
/// - A rotated access token rewrites the persisted (Hive) snapshot.
/// - `signedOut` while a session is still persisted means GoTrue gave up on
///   the refresh token (revoked / expired): [_onExpired] shows the
///   expired-session banner. A user logout clears the snapshot BEFORE calling
///   `signOut`, so it never reaches [_onExpired].
class AuthStateSync {
  AuthStateSync(this._local, this._onExpired);

  final AuthLocalDataSource _local;
  final Future<void> Function() _onExpired;

  Future<void> handle(sb.AuthState state) async {
    final current = await _local.readSession();
    if (current == null) {
      return;
    }
    if (state.event == sb.AuthChangeEvent.signedOut) {
      return _onExpired();
    }
    final session = state.session;
    if (session != null) {
      await _local.saveSession(
        AuthSession(user: current.user, token: session.accessToken),
      );
    }
  }
}
