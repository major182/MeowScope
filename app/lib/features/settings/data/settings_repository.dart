import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../calendar/domain/calendar_month.dart';
import '../../notifications/domain/notification_settings.dart';

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
        await _put(weekStartKey, value.name);
        await _enqueue(userId);
      });

  static const notificationsKey = 'settings.notifications';
  static const reminderHoursKey = 'settings.reminderHours';
  static const anomalyMethodKey = 'settings.anomalyMethod';

  /// 通知の設定を見張る（S-49）。未設定の項目は既定
  Stream<NotificationSettings> watchNotificationSettings() {
    final keys = [notificationsKey, reminderHoursKey, anomalyMethodKey];
    final q = _db.select(_db.appStates)..where((s) => s.key.isIn(keys));
    return q.watch().map((rows) {
      final values = {for (final r in rows) r.key: r.value};
      return NotificationSettings.parse(
        flagsJson: values[notificationsKey],
        reminderHours: values[reminderHoursKey],
        method: values[anomalyMethodKey],
      );
    });
  }

  /// 通知の設定を保存する。[userId] を渡すと、同期でアカウントの設定へ送る
  Future<void> setNotificationSettings(
    NotificationSettings value, {
    String? userId,
  }) => _db.transaction(() async {
    await _put(notificationsKey, jsonEncode(value.flags));
    await _put(reminderHoursKey, '${value.reminderHours}');
    await _put(anomalyMethodKey, value.method.name);
    await _enqueue(userId);
  });

  Future<void> _put(String key, String value) => _db
      .into(_db.appStates)
      .insertOnConflictUpdate(
        AppStatesCompanion.insert(key: key, value: value),
      );

  /// 設定は1行なので、送る内容は同期のときに端末の状態から作る（SyncEngine）。ここでは送る印だけを置く
  Future<void> _enqueue(String? userId) async {
    if (userId == null) {
      return;
    }
    await _db
        .into(_db.pendingChanges)
        .insert(
          PendingChangesCompanion.insert(
            userId: userId,
            targetTable: 'user_settings',
            rowId: userId,
            operation: 'upsert',
            payload: '{}',
          ),
        );
  }
}
