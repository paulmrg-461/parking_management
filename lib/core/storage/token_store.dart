import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the bearer token outside Hive (Keychain / Keystore / WebCrypto).
///
/// Hive is a plain-text local store: anything written there is readable from
/// a device backup or a rooted device, and the JWT grants full API access.
abstract class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}
