/// Read-only port over the current auth session, used by the network layer
/// (see `AuthInterceptor`) without depending on the auth feature.
abstract class SessionReader {
  /// The bearer token of the signed-in user, or `null` when signed out.
  Future<String?> currentToken();
}
