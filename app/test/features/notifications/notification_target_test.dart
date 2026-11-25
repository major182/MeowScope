import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/features/medication/domain/medication_plan.dart';
import 'package:meowscope/features/notifications/domain/anomaly.dart';
import 'package:meowscope/features/notifications/domain/birthday_plan.dart';
import 'package:meowscope/features/notifications/domain/family_plan.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';
import 'package:meowscope/features/notifications/domain/notification_target.dart';
import 'package:meowscope/features/notifications/domain/reminder_plan.dart';

/// 通知を押したときに開くおうち（BR-39）
void main() {
  group('UT-MH-12 開く場所におうちを添える・取り出す', () {
    test('問い合わせのない場所・ある場所に添えられ、取り出すと元に戻る', () {
      expect(withHousehold('/', 'h2'), '/?household=h2');
      final days = withHousehold('/days/2026-11-07?cat=c1', 'h2');
      expect(days, '/days/2026-11-07?cat=c1&household=h2');

      expect(splitHousehold('/?household=h2'), (householdId: 'h2', path: '/'));
      expect(splitHousehold(days), (
        householdId: 'h2',
        path: '/days/2026-11-07?cat=c1',
      ));
    });

    test('おうちが分からなければ添えない。添えていない場所は、おうちなしでそのまま返す', () {
      expect(withHousehold('/stats?cat=c1', null), '/stats?cat=c1');
      expect(splitHousehold('/stats?cat=c1'), (
        householdId: null,
        path: '/stats?cat=c1',
      ));
    });
  });

  group('UT-MH-13 どの通知も、押すとその猫のおうちを開く', () {
    final now = DateTime(2026, 11, 6, 12);

    test('記録忘れ・誕生日・お薬の時間', () {
      final reminder = planReminders(
        cats: const [ReminderCat(id: 'c2', name: 'タマ', householdId: 'h2')],
        lastRecordAt: {'c2': DateTime(2026, 11, 6, 8)},
        settings: const NotificationSettings(),
        now: now,
      );
      expect(reminder.single.notification.payload, '/?household=h2');

      final birthday = planBirthdays(
        cats: [
          BirthdayCat(
            id: 'c2',
            name: 'タマ',
            birthDate: DateTime(2020, 12, 1),
            householdId: 'h2',
          ),
        ],
        settings: const NotificationSettings(),
        now: now,
      );
      expect(birthday.single.notification.payload, '/?household=h2');

      final medication = planMedications(
        schedules: const [
          MedicationPlanItem(
            id: 'ms1',
            catName: 'タマ',
            name: '目薬',
            dose: null,
            timeOfDay: '08:00',
            enabled: true,
            householdId: 'h2',
          ),
        ],
        settings: const NotificationSettings(),
        now: now,
        android: true,
      );
      expect(medication.single.notification.payload, '/?household=h2');
    });

    test('いつもとの差', () {
      final n = anomalyNotification(
        Anomaly(
          catId: 'c2',
          catName: 'タマ',
          kind: 'food',
          direction: AnomalyDirection.low,
          day: DateTime(2026, 11, 5),
          observed: 1,
          usual: 3,
        ),
        method: AnomalyMethod.statistical,
        now: now,
        householdId: 'h2',
      );
      expect(n.payload, '/stats?cat=c2&kind=food&day=2026-11-05&household=h2');
    });
  });

  group('UT-MH-14 おうちの他の利用者の記録の通知', () {
    FamilyRecord rec(String id, String catId, String householdId) =>
        FamilyRecord(
          id: id,
          authorKey: 'u2',
          authorName: 'なつ',
          catName: catId == 'c1' ? 'ミケ' : 'タマ',
          typeName: 'ご飯',
          catId: catId,
          recordedAt: DateTime(2026, 11, 7, 8),
          householdId: householdId,
        );

    test('同じ人の記録でも、おうちが違えば別の通知にし、それぞれのおうちを開く', () {
      final n = familyNotifications([
        rec('r1', 'c1', 'h1'),
        rec('r2', 'c2', 'h2'),
        rec('r3', 'c1', 'h1'),
      ]);
      expect(n, hasLength(2));
      expect(n[0].title, 'なつさんが2件記録しました');
      expect(n[0].payload, '/days/2026-11-07?cat=c1&household=h1');
      expect(n[1].title, 'なつさんがタマのご飯を記録しました');
      expect(n[1].payload, '/days/2026-11-07?cat=c2&household=h2');
    });
  });
}
