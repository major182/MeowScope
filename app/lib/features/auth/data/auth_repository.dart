import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/db/app_database.dart';
import 'token_store.dart';

/// ログイン中のユーザー
class AuthUser {
  const AuthUser({required this.id, required this.name});

  final String id;

  /// 表示名。記録の投稿者名に使う（BR-17）
  final String name;
}

/// 端末の状態（app_states）に置くキー（DB 設計書 6章）
abstract final class SessionKeys {
  static const userId = 'session.userId';
  static const userName = 'session.userName';
  static const householdId = 'session.householdId';

  /// ユーザーごとに最後に選んだおうち。ログアウトしても残し、同じ人が入り直したら戻す
  static String householdOf(String userId) => 'household.$userId';
}

/// 新規登録・ログイン・ログアウト（S-01、S-02、API 設計書 2章）
///
/// トークンは OS の安全な保管場所に、ユーザーの ID と表示名は端末の DB に置く。
/// 失敗したときは [ApiError] を投げる
class AuthRepository {
  AuthRepository(this._db, this._api, this._tokens);

  final AppDatabase _db;
  final Dio _api;
  final TokenStore _tokens;

  /// ログイン中のユーザーを見張る。ログインしていなければ null
  Stream<AuthUser?> watchUser() {
    final query = _db.select(_db.appStates)
      ..where((s) => s.key.isIn([SessionKeys.userId, SessionKeys.userName]));
    return query.watch().map((rows) {
      final values = {for (final r in rows) r.key: r.value};
      final id = values[SessionKeys.userId];
      final name = values[SessionKeys.userName];
      return id == null || name == null ? null : AuthUser(id: id, name: name);
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) => _signIn('/auth/register', {
    'email': email.trim(),
    'password': password,
    'displayName': displayName.trim(),
  });

  Future<void> login({required String email, required String password}) =>
      _signIn('/auth/login', {'email': email.trim(), 'password': password});

  Future<void> _signIn(String path, Map<String, String> body) async {
    final Map<String, dynamic> data;
    try {
      final response = await _api.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(extra: {noAuth: true}),
      );
      data = response.data!;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
    await _tokens.save(
      AuthTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      ),
    );
    final user = data['user'] as Map<String, dynamic>;
    final userId = user['id'] as String;
    await _db.transaction(() async {
      final last =
          await (_db.select(_db.appStates)
                ..where((s) => s.key.equals(SessionKeys.householdOf(userId))))
              .getSingleOrNull();
      await _db.batch((b) {
        b.insertAllOnConflictUpdate(_db.appStates, [
          AppStatesCompanion.insert(key: SessionKeys.userId, value: userId),
          AppStatesCompanion.insert(
            key: SessionKeys.userName,
            value: user['displayName'] as String,
          ),
          if (last != null)
            AppStatesCompanion.insert(
              key: SessionKeys.householdId,
              value: last.value,
            ),
        ]);
        // 前に入っていた別の人のおうちを見せない（API 設計書 2章）
        if (last == null) {
          b.deleteWhere(
            _db.appStates,
            (s) => s.key.equals(SessionKeys.householdId),
          );
        }
      });
    });
  }

  /// ログアウトする。サーバーにつながらなくても、端末ではログアウトを済ませる
  ///
  /// 同期の実装までは、端末のデータはユーザーの ID と結び付けたまま残す（API 設計書 2章）
  Future<void> logout() async {
    final saved = await _tokens.read();
    if (saved != null) {
      try {
        await _api.post<void>(
          '/auth/logout',
          data: {'refreshToken': saved.refreshToken},
        );
      } on DioException {
        // つながらなくても、トークンは30日で期限が切れる
      }
    }
    await _tokens.clear();
    await (_db.delete(_db.appStates)..where(
          (s) => s.key.isIn([
            SessionKeys.userId,
            SessionKeys.userName,
            SessionKeys.householdId,
          ]),
        ))
        .go();
  }
}
