import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers.dart';
import '../data/notification_scheduler.dart';
import '../domain/reminder_plan.dart';

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
  );
});

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

  @override
  void initState() {
    super.initState();
    _scheduler = ref.read(notificationSchedulerProvider);
    // 予約の材料が変わるたびに、予約を置き換える。開いた時点の予約も、すぐに作る
    ref.listenManual(reminderPlanProvider, (_, plan) {
      if (plan != null) {
        _scheduler.replace('reminder', plan);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _scheduler.clear('reminder');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
