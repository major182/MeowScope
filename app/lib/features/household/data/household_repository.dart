import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../records/data/record_repository.dart';

/// ログイン中のユーザーと、選んでいるおうち
class Session {
  const Session({required this.author, required this.householdId});

  final Author author;
  final String householdId;
}

/// 端末の状態に保存するキー
abstract final class _Keys {
  static const userId = 'session.userId';
  static const userName = 'session.userName';
  static const householdId = 'session.householdId';
}

/// おうちの作成と、端末に保存するセッション
///
/// ログインができるまでは、おうちを作った人を端末だけの仮の利用者として保存する。
/// 認証の実装で、ログインしたユーザーに置き換える
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
      final userId = values[_Keys.userId];
      final userName = values[_Keys.userName];
      final householdId = values[_Keys.householdId];
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
    required String userName,
  }) {
    final householdId = _uuid.v4();
    final userId = _uuid.v4();
    final now = _clock().toUtc();
    final name = householdName.trim();
    final author = Author(id: userId, name: userName.trim());
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
              operation: 'upsert',
              payload: jsonEncode({'name': name}),
            ),
          );
      await _records.addStandardTypes(householdId);
      await _db.batch((b) {
        b.insertAllOnConflictUpdate(_db.appStates, [
          AppStatesCompanion.insert(key: _Keys.userId, value: userId),
          AppStatesCompanion.insert(key: _Keys.userName, value: author.name),
          AppStatesCompanion.insert(key: _Keys.householdId, value: householdId),
        ]);
      });
      return Session(author: author, householdId: householdId);
    });
  }
}
