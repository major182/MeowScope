import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../domain/reminder_plan.dart';
import 'notifier.dart';

/// 予約した通知を、種類ごとに置き換える
///
/// 予約した id と時刻は端末の状態（app_states の `notify.scheduled.<種類>`）に残す。毎日の繰り返しは時刻の代わりに
/// [dailyMark] を残す（時刻が過ぎても次の日にまた出るので、要らなくなったらいつでも取り消す）。
/// Android の予約はアプリを閉じても残るので、次に起動したときも、要らなくなった予約を取り消せるようにするため
class NotificationScheduler {
  NotificationScheduler(this._db, this._notifier, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final AppNotifier _notifier;
  final DateTime Function() _clock;

  static String key(String kind) => 'notify.scheduled.$kind';

  /// 毎日の繰り返しの予約の印
  static const dailyMark = -1;

  /// [kind] の予約を [plan] に置き換える。前の予約のうち、[plan] になく、まだ時刻の来ていないものは取り消す
  ///
  /// 時刻を過ぎた予約は、もう知らせている。取り消すと出ている通知まで消えてしまうので、覚えておくのをやめるだけにする
  Future<void> replace(String kind, List<PlannedNotification> plan) async {
    final now = _clock();
    final before = await _scheduled(kind);
    final after = {
      for (final p in plan)
        p.notification.id: p.daily ? dailyMark : p.at.millisecondsSinceEpoch,
    };
    for (final MapEntry(key: id, value: at) in before.entries) {
      if (!after.containsKey(id) &&
          (at == dailyMark || at > now.millisecondsSinceEpoch)) {
        await _notifier.cancel(id);
      }
    }
    for (final p in plan) {
      await _notifier.schedule(p.notification, p.at, daily: p.daily);
    }
    // 予約が変わらなければ書かない。端末の状態の表を書くと、同じ表を見張る通知の設定が流れ直し、
    // 予約の計算と書き込みを繰り返してしまうため
    if (_same(before, after)) {
      return;
    }
    await _db
        .into(_db.appStates)
        .insertOnConflictUpdate(
          AppStatesCompanion.insert(
            key: key(kind),
            value: jsonEncode({
              for (final e in after.entries) '${e.key}': e.value,
            }),
          ),
        );
  }

  /// [kind] の予約をすべて取り消す（ログアウトのときなど）。時刻を過ぎて出ている通知は残す
  Future<void> clear(String kind) => replace(kind, const []);

  static bool _same(Map<int, int> a, Map<int, int> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  Future<Map<int, int>> _scheduled(String kind) async {
    final row = await (_db.select(
      _db.appStates,
    )..where((s) => s.key.equals(key(kind)))).getSingleOrNull();
    if (row == null) {
      return {};
    }
    try {
      final decoded = jsonDecode(row.value) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries) int.parse(e.key): e.value as int,
      };
    } on Object {
      return {};
    }
  }
}
