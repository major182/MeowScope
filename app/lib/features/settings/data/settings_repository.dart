import '../../../core/db/app_database.dart';
import '../../calendar/domain/calendar_month.dart';

/// 端末に置くユーザーの設定。
/// 同期の実装までは端末の状態（app_states）に置き、同期で user_settings へ移す
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

  /// 週の始まりを保存する
  Future<void> setWeekStart(WeekStart value) => _db
      .into(_db.appStates)
      .insertOnConflictUpdate(
        AppStatesCompanion.insert(key: weekStartKey, value: value.name),
      );
}
