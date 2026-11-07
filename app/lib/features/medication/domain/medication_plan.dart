import '../../notifications/data/notifier.dart';
import '../../notifications/domain/notification_settings.dart';
import '../../notifications/domain/reminder_plan.dart';

/// 予定の時刻（`HH:mm`）を時と分にする。形が違えば null
({int hour, int minute})? parseTimeOfDay(String text) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(text);
  if (match == null) {
    return null;
  }
  return (hour: int.parse(match[1]!), minute: int.parse(match[2]!));
}

/// 時と分を予定の時刻（`HH:mm`）にする
String formatTimeOfDay(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// 通知の対象の予定（お別れ・削除した猫の予定は渡さない）
class MedicationPlanItem {
  const MedicationPlanItem({
    required this.id,
    required this.catName,
    required this.name,
    required this.dose,
    required this.timeOfDay,
    required this.enabled,
  });

  final String id;
  final String catName;
  final String name;
  final String? dose;
  final String timeOfDay;
  final bool enabled;
}

/// お薬の時間の予約（F-NT-01、BR-06）
///
/// オンの予定ごとに、毎日その時刻に知らせる。最初の時刻は、今日の時刻がまだなら今日、過ぎていれば明日。
/// 繰り返しは端末（Android）に任せるので、アプリを何日も開かなくても毎日出る。
/// Windows では知らせない（BR-09）
List<PlannedNotification> planMedications({
  required List<MedicationPlanItem> schedules,
  required NotificationSettings settings,
  required DateTime now,
  required bool android,
}) {
  if (!settings.shouldNotify(NotificationKind.medication, android: android)) {
    return const [];
  }
  return [
    for (final s in schedules)
      if (s.enabled)
        if (parseTimeOfDay(s.timeOfDay) case final t?)
          PlannedNotification(
            AppNotification(
              id: notificationId('medication', s.id),
              title: '${s.catName}のお薬の時間です',
              body: s.dose == null ? s.name : '${s.name} ${s.dose}',
              payload: '/',
            ),
            _next(now, t.hour, t.minute),
            daily: true,
          ),
  ];
}

/// [now] より後で、最初に [hour]:[minute] になる時刻。ちょうど今の時刻なら明日
DateTime _next(DateTime now, int hour, int minute) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, hour, minute);
}
