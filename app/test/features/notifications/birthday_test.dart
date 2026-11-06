import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/notifications/domain/birthday_plan.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';

void main() {
  const settings = NotificationSettings();
  final mike = BirthdayCat(
    id: 'c1',
    name: 'ミケ',
    birthDate: DateTime(2023, 11, 10),
  );

  List<DateTime> at(DateTime now, {BirthdayCat? cat, bool android = true}) =>
      planBirthdays(
        cats: [cat ?? mike],
        settings: settings,
        now: now,
        android: android,
      ).map((p) => p.at).toList();

  test('UT-BD-01 次の誕生日の朝9時に「今日はミケの誕生日です。3歳おめでとう！」を予約する', () {
    final p = planBirthdays(
      cats: [mike],
      settings: settings,
      now: DateTime(2026, 11, 6, 12),
    );
    expect(p.single.at, DateTime(2026, 11, 10, 9));
    expect(p.single.notification.title, '今日はミケの誕生日です。3歳おめでとう！');
  });

  test('UT-BD-02 境界値：誕生日の9時ちょうど・過ぎていれば来年、1ミリ秒前なら今年', () {
    expect(at(DateTime(2026, 11, 10, 9)), [DateTime(2027, 11, 10, 9)]);
    expect(at(DateTime(2026, 11, 10, 20)), [DateTime(2027, 11, 10, 9)]);
    expect(at(DateTime(2026, 11, 10, 8, 59, 59, 999)), [
      DateTime(2026, 11, 10, 9),
    ]);
  });

  test('UT-BD-03 生まれた年（0歳）の誕生日は知らせず、翌年の1歳から知らせる', () {
    final baby = BirthdayCat(
      id: 'c2',
      name: 'タマ',
      birthDate: DateTime(2026, 3, 1),
    );
    final p = planBirthdays(
      cats: [baby],
      settings: settings,
      now: DateTime(2026, 2, 1),
    );
    expect(p.single.at, DateTime(2027, 3, 1, 9));
    expect(p.single.notification.title, '今日はタマの誕生日です。1歳おめでとう！');
  });

  test('UT-BD-04 2月29日生まれは、うるう年でない年は2月28日に祝う', () {
    final leap = BirthdayCat(
      id: 'c3',
      name: 'うる',
      birthDate: DateTime(2024, 2, 29),
    );
    expect(at(DateTime(2026, 1, 1), cat: leap), [DateTime(2026, 2, 28, 9)]);
    expect(at(DateTime(2027, 12, 1), cat: leap), [DateTime(2028, 2, 29, 9)]);
    expect(isBirthday(leap.birthDate, DateTime(2026, 2, 28)), isTrue);
    expect(isBirthday(leap.birthDate, DateTime(2028, 2, 28)), isFalse);
    expect(isBirthday(leap.birthDate, DateTime(2028, 2, 29)), isTrue);
  });

  test('UT-BD-05 誕生日の通知がオフなら予約しない。Windows でも予約する（BR-09）', () {
    final off = settings.toggled(NotificationKind.birthday, false);
    expect(
      planBirthdays(cats: [mike], settings: off, now: DateTime(2026, 11, 6)),
      isEmpty,
    );
    expect(at(DateTime(2026, 11, 6), android: false), hasLength(1));
  });

  test('UT-BD-06 保存した生年月日（UTC の0時）は、端末の地域の時刻にかかわらず同じ年月日として読む', () {
    expect(birthDateOf(DateTime.utc(2023, 11, 10)), DateTime(2023, 11, 10));
  });
}
