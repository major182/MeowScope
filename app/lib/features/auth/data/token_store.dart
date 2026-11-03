import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ログインのトークンの組
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// トークンの保管場所。テストではメモリーに置く版に差し替える
abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> save(AuthTokens tokens);
  Future<void> clear();
}

/// OS の安全な保管場所に置く（NF-SC-07）。Android は Keystore、Windows は資格情報の保管庫を使う
///
/// トークンは端末の DB には置かない。DB のファイルはコピーされても読めてしまうため
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _access = 'auth.accessToken';
  static const _refresh = 'auth.refreshToken';

  @override
  Future<AuthTokens?> read() async {
    final access = await _storage.read(key: _access);
    final refresh = await _storage.read(key: _refresh);
    if (access == null || refresh == null) {
      return null;
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> save(AuthTokens tokens) async {
    await _storage.write(key: _access, value: tokens.accessToken);
    await _storage.write(key: _refresh, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}
