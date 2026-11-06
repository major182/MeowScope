import '../data/notifier.dart';
import 'notification_settings.dart';

/// 予約する通知。[at] の時刻に [notification] を知らせる
class PlannedNotification {
  const PlannedNotification(this.notification, this.at);

  final AppNotification notification;
  final DateTime at;
}

/// 記録忘れの対象の猫（お別れの猫は渡さない）
class ReminderCat {
  const ReminderCat({required this.id, required this.name});

  final String id;
  final String name;
}

/// 通知の id。種類と対象（猫の ID など）から、いつも同じ値を作る（予約を置き換え・取り消すため）。
/// Dart の hashCode は実行ごとに同じとは限らないので、FNV-1a で計算する。Android の通知の id は 32 ビットの整数
int notificationId(String kind, String key) {
  var hash = 0x811c9dc5;
  for (final unit in '$kind:$key'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// 記録忘れの予約（BR-13、F-NT-03）
///
/// 猫ごとに、その猫の最後の記録（家族の記録を含む）から n 時間後に知らせる。
/// 記録が1件もない猫と、知らせる時刻がもう過ぎた猫は予約しない（開いた直後にまとめて出さないため）
List<PlannedNotification> planReminders({
  required List<ReminderCat> cats,
  required Map<String, DateTime> lastRecordAt,
  required NotificationSettings settings,
  required DateTime now,
}) {
  if (!settings.isOn(NotificationKind.reminder)) {
    return const [];
  }
  final hours = settings.reminderHours;
  return [
    for (final cat in cats)
      if (lastRecordAt[cat.id] case final last?)
        if (last.add(Duration(hours: hours)) case final at when at.isAfter(now))
          PlannedNotification(
            AppNotification(
              id: notificationId('reminder', cat.id),
              title: '${cat.name}の記録が$hours時間ありません',
              payload: '/',
            ),
            at,
          ),
  ];
}
