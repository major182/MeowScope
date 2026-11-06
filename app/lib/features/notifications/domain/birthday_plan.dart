import '../data/notifier.dart';
import 'notification_settings.dart';
import 'reminder_plan.dart';

/// 誕生日の対象の猫（お別れの猫と、生年月日のない猫は渡さない。BR-32）
class BirthdayCat {
  const BirthdayCat({
    required this.id,
    required this.name,
    required this.birthDate,
  });

  final String id;
  final String name;
  final DateTime birthDate;
}

/// 保存した生年月日（UTC の0時で保存している）を、端末の日付に戻す。地域の時刻に直すと日付がずれることがあるので、年月日だけを使う
DateTime birthDateOf(DateTime stored) {
  final utc = stored.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// お祝いの通知を出す時刻（朝9時。BR-32）
const birthdayHour = 9;

/// [year] 年の誕生日。2月29日生まれは、うるう年でない年は2月28日にする
DateTime birthdayIn(DateTime birthDate, int year) {
  final leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  if (birthDate.month == 2 && birthDate.day == 29 && !leap) {
    return DateTime(year, 2, 28);
  }
  return DateTime(year, birthDate.month, birthDate.day);
}

/// [day] が誕生日か（年は見ない。カレンダーの印に使う。F-VW-05）
bool isBirthday(DateTime birthDate, DateTime day) {
  final b = birthdayIn(birthDate, day.year);
  return b.month == day.month && b.day == day.day;
}

/// 誕生日のお祝いの予約（F-NT-06、BR-32）
///
/// 猫ごとに、次の誕生日の朝9時に「今日はミケの誕生日です。3歳おめでとう！」を予約する。
/// 今年の誕生日の9時を過ぎていたら、来年の誕生日にする（過ぎた分は出さない）
List<PlannedNotification> planBirthdays({
  required List<BirthdayCat> cats,
  required NotificationSettings settings,
  required DateTime now,
  bool android = true,
}) {
  if (!settings.shouldNotify(NotificationKind.birthday, android: android)) {
    return const [];
  }
  return [
    for (final cat in cats)
      if (_next(cat.birthDate, now) case final at?)
        PlannedNotification(
          AppNotification(
            id: notificationId('birthday', cat.id),
            title:
                '今日は${cat.name}の誕生日です。${at.year - cat.birthDate.year}歳おめでとう！',
            payload: '/',
          ),
          at,
        ),
  ];
}

/// 次に知らせる時刻。生まれた年（0歳）の誕生日は知らせない
DateTime? _next(DateTime birthDate, DateTime now) {
  for (final year in [now.year, now.year + 1]) {
    final day = birthdayIn(birthDate, year);
    final at = DateTime(day.year, day.month, day.day, birthdayHour);
    if (year > birthDate.year && at.isAfter(now)) {
      return at;
    }
  }
  return null;
}
