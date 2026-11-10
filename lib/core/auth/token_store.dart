import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  // Debug Android installations can contain preferences restored without
  // their original Keystore key. Use a separate encrypted store for debug.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: kDebugMode ? 'finai_debug_session' : null,
    ),
  );
  static const _key = 'finai_access_token';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
