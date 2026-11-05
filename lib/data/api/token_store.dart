import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the refresh token survives an app restart ("Remember me" on). The access token is
/// never stored; it lives in memory in the session. Tokens are never logged.
abstract class TokenStore {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<void> clear();
}

/// Android Keystore / iOS Keychain via flutter_secure_storage.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'auth.refreshToken';

  @override
  Future<String?> readRefreshToken() async {
    try {
      final v = await _storage.read(key: _key);
      return v == null || v.isEmpty ? null : v;
    } catch (_) {
      return null; // unreadable (e.g. keystore reset): sign in again
    }
  }

  @override
  Future<void> writeRefreshToken(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      // Not stored: the user signs in again next time.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

/// In memory (tests).
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.refreshToken]);

  String? refreshToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String token) async => refreshToken = token;

  @override
  Future<void> clear() async => refreshToken = null;
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
