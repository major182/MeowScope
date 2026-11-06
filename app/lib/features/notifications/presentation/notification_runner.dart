import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../../sync/presentation/sync_controller.dart';
import '../data/anomaly_alerts.dart';
import '../data/notification_scheduler.dart';
import '../domain/birthday_plan.dart';
import '../domain/reminder_plan.dart';

final anomalyAlertsProvider = Provider<AnomalyAlerts>(
  (ref) => AnomalyAlerts(
    ref.watch(databaseProvider),
    ref.watch(recordRepositoryProvider),
    ref.watch(notifierProvider),
  ),
);

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => NotificationScheduler(
    ref.watch(databaseProvider),
    ref.watch(notifierProvider),
  ),
);

/// 記録忘れの対象の猫（お別れを除く。BR-13）
final _activeCatsProvider = StreamProvider.autoDispose<List<CatRow>>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(recordRepositoryProvider)
      .watchActiveCats(session.householdId);
});

/// 猫ごとの最後の記録の日時（家族の記録を含む）
final _lastRecordTimesProvider =
    StreamProvider.autoDispose<Map<String, DateTime>>((ref) {
      final session = ref.watch(sessionProvider).value;
      if (session == null) {
        return Stream.value(const {});
      }
      return ref
          .watch(recordRepositoryProvider)
          .watchLastRecordTimes(session.householdId);
    });

/// 記録忘れの予約。材料がそろうまでは null
///
/// 記録・同期で受け取った記録・猫・通知の設定のどれかが変わるたびに計算し直す
final reminderPlanProvider = Provider.autoDispose<List<PlannedNotification>?>((
  ref,
) {
  final cats = ref.watch(_activeCatsProvider).value;
  final last = ref.watch(_lastRecordTimesProvider).value;
  final settings = ref.watch(notificationSettingsProvider).value;
  if (cats == null || last == null || settings == null) {
    return null;
  }
  return planReminders(
    cats: [for (final c in cats) ReminderCat(id: c.id, name: c.name)],
    lastRecordAt: last,
    settings: settings,
    now: DateTime.now(),
    android: defaultTargetPlatform == TargetPlatform.android,
  );
});

/// 誕生日のお祝いの予約（F-NT-06、BR-32）。猫（生年月日・お別れ）と通知の設定が変わるたびに計算し直す
final birthdayPlanProvider = Provider.autoDispose<List<PlannedNotification>?>((
  ref,
) {
  final cats = ref.watch(_activeCatsProvider).value;
  final settings = ref.watch(notificationSettingsProvider).value;
  if (cats == null || settings == null) {
    return null;
  }
  return planBirthdays(
    cats: [
      for (final c in cats)
        if (c.birthDate case final birth?)
          BirthdayCat(id: c.id, name: c.name, birthDate: birthDateOf(birth)),
    ],
    settings: settings,
    now: DateTime.now(),
    android: defaultTargetPlatform == TargetPlatform.android,
  );
});

/// 同期が終わって成功したところか（実行中から、失敗もログインの期限切れもない状態に変わった）
bool syncJustSucceeded(SyncState? previous, SyncState next) =>
    (previous?.running ?? false) &&
    !next.running &&
    next.error == null &&
    !next.needsLogin;

/// 予約の種類と、その予約の計算
final _plans = {
  'reminder': reminderPlanProvider,
  'birthday': birthdayPlanProvider,
};

/// ログイン中に、通知の予約を最新に保つ（F-NT-03 など）
///
/// ログアウトなどでこの部品が消えたら、予約を取り消す（ほかの人の猫について知らせないため）
class NotificationRunner extends ConsumerStatefulWidget {
  const NotificationRunner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationRunner> createState() => _NotificationRunnerState();
}

class _NotificationRunnerState extends ConsumerState<NotificationRunner> {
  late final NotificationScheduler _scheduler;

  /// 起動してから、いつもとの差を判定したか（起動時の同期のあとに1回だけ。BR-05）
  var _anomalyChecked = false;

  @override
  void initState() {
    super.initState();
    _scheduler = ref.read(notificationSchedulerProvider);
    // 予約の材料が変わるたびに、種類ごとに予約を置き換える。開いた時点の予約も、すぐに作る
    for (final MapEntry(key: kind, value: provider) in _plans.entries) {
      ref.listenManual(provider, (_, plan) {
        if (plan != null) {
          _scheduler.replace(kind, plan);
        }
      }, fireImmediately: true);
    }
    // 起動時の同期が成功したら、いつもとの差を判定する。失敗したら判定せず、次に成功した同期を待つ（BR-05）
    ref.listenManual(syncControllerProvider, (previous, next) {
      if (syncJustSucceeded(previous, next) && !_anomalyChecked) {
        _anomalyChecked = true;
        _checkAnomalies();
      }
    });
  }

  Future<void> _checkAnomalies() async {
    final log = ref.read(appLogProvider);
    try {
      final session = ref.read(sessionProvider).value;
      final settings = await ref.read(notificationSettingsProvider.future);
      if (session == null || !mounted) {
        return;
      }
      await ref
          .read(anomalyAlertsProvider)
          .check(
            householdId: session.householdId,
            settings: settings,
            android: defaultTargetPlatform == TargetPlatform.android,
          );
    } on Object catch (e) {
      // 判定に失敗しても、アプリの操作は止めない。例外の種類だけをログに残す
      await log.record('warning', 'いつもとの差の判定に失敗：${e.runtimeType}');
    }
  }

  @override
  void dispose() {
    for (final kind in _plans.keys) {
      _scheduler.clear(kind);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
