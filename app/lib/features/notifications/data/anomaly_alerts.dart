import '../../../core/db/app_database.dart';
import '../../records/data/record_repository.dart';
import '../domain/anomaly.dart';
import '../domain/notification_settings.dart';
import 'notifier.dart';

/// いつもとの差を判定して知らせる（F-NT-02、BR-05・12）
///
/// 同じ猫・同じ種類は1日1回まで。知らせた日を端末の状態（app_states の `notify.anomaly.<猫の ID>.<種類>`）に残す
class AnomalyAlerts {
  AnomalyAlerts(
    this._db,
    this._records,
    this._notifier, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final RecordRepository _records;
  final AppNotifier _notifier;
  final DateTime Function() _clock;

  static String key(String catId, String kind) => 'notify.anomaly.$catId.$kind';

  /// [householdId] の猫を判定し、まだ今日知らせていないものを知らせる。知らせた数を返す
  Future<int> check({
    required String householdId,
    required NotificationSettings settings,
    required bool android,
  }) async {
    if (!settings.shouldNotify(NotificationKind.anomaly, android: android)) {
      return 0;
    }
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final cats = await _records.activeCats(householdId);
    final records = await _records.range(
      householdId,
      from: today.subtract(const Duration(days: usualDays + 1)),
      to: today.add(const Duration(days: 1)),
    );
    final anomalies = detectAnomalies(
      cats: [
        for (final c in cats)
          AnomalyCat(id: c.id, name: c.name, thresholds: c.anomalyThresholds),
      ],
      records: [
        for (final r in records)
          AnomalyRecord(
            catId: r.catId,
            kind: r.kind,
            recordedAt: r.recordedAt,
            valueNumber: r.valueNumber,
          ),
      ],
      method: settings.method,
      now: now,
    );
    final todayText = '${today.year}-${today.month}-${today.day}';
    var shown = 0;
    for (final a in anomalies) {
      final k = key(a.catId, a.kind);
      final row = await (_db.select(
        _db.appStates,
      )..where((s) => s.key.equals(k))).getSingleOrNull();
      if (row?.value == todayText) {
        continue;
      }
      await _notifier.show(
        anomalyNotification(a, method: settings.method, now: now),
      );
      await _db
          .into(_db.appStates)
          .insertOnConflictUpdate(
            AppStatesCompanion.insert(key: k, value: todayText),
          );
      shown++;
    }
    return shown;
  }
}
