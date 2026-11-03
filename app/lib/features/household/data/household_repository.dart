import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../auth/data/auth_repository.dart';
import '../../records/data/record_repository.dart';

/// ログイン中のユーザーと、選んでいるおうち
class Session {
  const Session({required this.author, required this.householdId});

  final Author author;
  final String householdId;
}

/// おうちの作成と、端末に保存するセッション
///
/// おうちを作った人は、ログイン中のユーザー（[AuthUser]）
class HouseholdRepository {
  HouseholdRepository(
    this._db,
    this._records, {
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final RecordRepository _records;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// セッションを見張る。おうちがまだなければ null
  Stream<Session?> watchSession() {
    return _db.select(_db.appStates).watch().map((rows) {
      final values = {for (final r in rows) r.key: r.value};
      final userId = values[SessionKeys.userId];
      final userName = values[SessionKeys.userName];
      final householdId = values[SessionKeys.householdId];
      if (userId == null || userName == null || householdId == null) {
        return null;
      }
      return Session(
        author: Author(id: userId, name: userName),
        householdId: householdId,
      );
    });
  }

  /// おうちを作り、標準の記録項目を登録して、そのおうちを選んだ状態にする
  Future<Session> createHousehold({
    required String householdName,
    required AuthUser user,
  }) {
    final householdId = _uuid.v4();
    final userId = user.id;
    final now = _clock().toUtc();
    final name = householdName.trim();
    final author = Author(id: userId, name: user.name);
    return _db.transaction(() async {
      await _db
          .into(_db.households)
          .insert(
            HouseholdsCompanion.insert(
              id: householdId,
              createdAt: now,
              updatedAt: now,
              name: name,
            ),
          );
      await _db
          .into(_db.pendingChanges)
          .insert(
            PendingChangesCompanion.insert(
              userId: userId,
              targetTable: 'households',
              rowId: householdId,
              // 作成は POST /households で送る（同期の処理が見分ける）
              operation: 'create',
              payload: jsonEncode({'name': name}),
            ),
          );
      await _records.addStandardTypes(householdId);
      await _db.batch((b) {
        b.insertAllOnConflictUpdate(_db.appStates, [
          AppStatesCompanion.insert(
            key: SessionKeys.householdId,
            value: householdId,
          ),
          // ログアウトして入り直したときに、このおうちへ戻す
          AppStatesCompanion.insert(
            key: SessionKeys.householdOf(userId),
            value: householdId,
          ),
        ]);
      });
      return Session(author: author, householdId: householdId);
    });
  }
}
