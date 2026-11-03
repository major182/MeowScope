import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../calendar/domain/calendar_month.dart';

/// 端末に置くユーザーの設定
///
/// サーバーではアカウントの設定（user_settings）に保存し、機種変更でも引き継ぐ（BR-22、AC-13）。
/// 端末では端末の状態（app_states）に置き、同期で送受信する
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const weekStartKey = 'settings.weekStart';

  /// 週の始まりを見張る。未設定なら日曜
  Stream<WeekStart> watchWeekStart() {
    final q = _db.select(_db.appStates)
      ..where((s) => s.key.equals(weekStartKey));
    return q.watchSingleOrNull().map((row) => WeekStart.parse(row?.value));
  }

  /// 週の始まりを保存する。[userId] を渡すと、同期でアカウントの設定へ送る
  Future<void> setWeekStart(WeekStart value, {String? userId}) =>
      _db.transaction(() async {
        await _db
            .into(_db.appStates)
            .insertOnConflictUpdate(
              AppStatesCompanion.insert(key: weekStartKey, value: value.name),
            );
        if (userId != null) {
          await _db
              .into(_db.pendingChanges)
              .insert(
                PendingChangesCompanion.insert(
                  userId: userId,
                  targetTable: 'user_settings',
                  rowId: userId,
                  operation: 'upsert',
                  payload: jsonEncode({'weekStart': value.name}),
                ),
              );
        }
      });
}
