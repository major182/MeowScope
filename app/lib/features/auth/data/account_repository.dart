import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/api/api_error.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/local_cleanup.dart';
import '../../icons/icon_repository.dart';
import 'auth_repository.dart';
import 'token_store.dart';

/// おうちのメンバー（S-42）
class Member {
  const Member({
    required this.userId,
    required this.name,
    this.hasIcon = false,
    this.iconSeq,
  });

  final String userId;
  final String name;
  final bool hasIcon;
  final int? iconSeq;

  IconRef get icon =>
      IconRef(IconOwner.user, userId, hasIcon: hasIcon, version: iconSeq);
}

/// アカウントとおうちの管理（S-42、S-45、API 設計書 3〜4章）
///
/// 名前の変更（おうち）は同期で送るので、オフラインでもできる。
/// それ以外（表示名・パスワードの変更、抜ける、退会）はサーバーで行うため、通信が要る。失敗したら [ApiError] を投げる
class AccountRepository {
  AccountRepository(
    this._db,
    this._api,
    this._tokens, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Dio _api;
  final TokenStore _tokens;
  final DateTime Function() _clock;

  /// おうちの名前
  Stream<String?> watchHouseholdName(String householdId) =>
      (_db.select(_db.households)..where((h) => h.id.equals(householdId)))
          .watchSingleOrNull()
          .map((h) => h?.name);

  /// おうちの今のメンバー（同期で受け取ったもの）。名前の順
  Stream<List<Member>> watchMembers(String householdId) {
    final query = _db.select(_db.householdMembers)
      ..where(
        (m) =>
            m.householdId.equals(householdId) &
            m.deletedAt.isNull() &
            m.userId.isNotNull(),
      );
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          Member(
            userId: r.userId!,
            name: r.displayName ?? '',
            hasIcon: r.hasIcon,
            iconSeq: r.iconSeq,
          ),
      ]..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  /// 自分のアイコン。同期でメンバーの行が届くまでは、端末で設定したものだけを出す
  Stream<IconRef> watchMyIcon(String userId) {
    final query = _db.select(_db.householdMembers)
      ..where((m) => m.userId.equals(userId))
      ..limit(1);
    return query.watch().map(
      (rows) => rows.isEmpty
          ? IconRef(IconOwner.user, userId)
          : IconRef(
              IconOwner.user,
              userId,
              hasIcon: rows.first.hasIcon,
              version: rows.first.iconSeq,
            ),
    );
  }

  /// おうちの名前を変える。同期待ちに入れ、次の同期で送る
  Future<void> renameHousehold({
    required String householdId,
    required String userId,
    required String name,
  }) => _db.transaction(() async {
    final trimmed = name.trim();
    await (_db.update(
      _db.households,
    )..where((h) => h.id.equals(householdId))).write(
      HouseholdsCompanion(
        name: Value(trimmed),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
    await _db
        .into(_db.pendingChanges)
        .insert(
          PendingChangesCompanion.insert(
            userId: userId,
            targetTable: 'households',
            rowId: householdId,
            operation: 'upsert',
            payload: jsonEncode({'name': trimmed}),
          ),
        );
  });

  /// 招待のリンクを作り、LINE などで送る文を返す（1時間・1回だけ有効）
  Future<String> createInvitation({
    required String householdId,
    required String householdName,
  }) async {
    final Map<String, dynamic> body;
    try {
      body = (await _api.post<Map<String, dynamic>>(
        '/households/$householdId/invitations',
      )).data!;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
    return invitationMessage(householdName, body['link'] as String);
  }

  /// 招待を受ける。参加したおうちを選んだ状態にする（中身は続く同期で届く）
  Future<void> acceptInvitation({
    required String userId,
    required String token,
  }) async {
    final Map<String, dynamic> body;
    try {
      body = (await _api.post<Map<String, dynamic>>(
        '/invitations/accept',
        data: {'token': token},
      )).data!;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
    final householdId = body['householdId'] as String;
    // 同期が届くまでの間も S-04 に戻らないよう、名前は仮に入れておく（同期で正しい名前になる）
    await _db.transaction(() async {
      await _db
          .into(_db.households)
          .insertOnConflictUpdate(
            HouseholdsCompanion.insert(
              id: householdId,
              createdAt: _clock().toUtc(),
              updatedAt: _clock().toUtc(),
              name: '',
            ),
          );
      for (final key in [
        SessionKeys.householdId,
        SessionKeys.householdOf(userId),
      ]) {
        await _db
            .into(_db.appStates)
            .insertOnConflictUpdate(
              AppStatesCompanion.insert(key: key, value: householdId),
            );
      }
    });
  }

  /// 表示名を変える。これからの記録の投稿者名になる（過去の記録の投稿者名は変えない。BR-17）
  Future<void> rename(String name) async {
    final Map<String, dynamic> body;
    try {
      body = (await _api.patch<Map<String, dynamic>>(
        '/me',
        data: {'displayName': name.trim()},
      )).data!;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
    await _db
        .into(_db.appStates)
        .insertOnConflictUpdate(
          AppStatesCompanion.insert(
            key: SessionKeys.userName,
            value: body['displayName'] as String,
          ),
        );
  }

  /// パスワードを変える。他の端末のログインは無効になり、この端末は新しいトークンに替える
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    final Map<String, dynamic> body;
    try {
      body = (await _api.put<Map<String, dynamic>>(
        '/me/password',
        data: {'currentPassword': current, 'newPassword': next},
      )).data!;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
    await _tokens.save(
      AuthTokens(
        accessToken: body['accessToken'] as String,
        refreshToken: body['refreshToken'] as String,
      ),
    );
  }

  /// おうちを抜ける（BR-16、BR-19）。端末からそのおうちのデータを消し、おうちの作成（S-04）へ戻る
  Future<void> leaveHousehold({
    required String userId,
    required String householdId,
    required bool keepRecords,
  }) async {
    try {
      await _api.post<void>(
        '/households/$householdId/leave',
        data: {'keepRecords': keepRecords},
      );
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
    await _db.transaction(
      () => removeHouseholdLocally(_db, userId, householdId),
    );
  }

  /// 退会する（BR-15、BR-16）。端末のデータとトークンを消し、ログイン（S-01）へ戻る
  Future<void> deleteAccount({
    required String userId,
    required bool keepRecords,
  }) async {
    try {
      await _api.delete<void>('/me', data: {'keepRecords': keepRecords});
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
    await _tokens.clear();
    await _db.transaction(() async {
      await (_db.delete(
        _db.pendingChanges,
      )..where((p) => p.userId.equals(userId))).go();
      await wipeLocalData(_db);
    });
  }
}

/// LINE などで送る招待の文（画面設計書 S-42）
String invitationMessage(String householdName, String link) =>
    'MeowScope のおうち「$householdName」への招待です。1時間以内に、1回だけ使えます。\n'
    '$link\n'
    'リンクを押しても開かないときは、アプリの「招待されたおうちに参加」にこの文をそのまま貼り付けてください。';
