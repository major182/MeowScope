import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/medication/domain/medication_plan.dart';
import 'package:meowscope/features/notifications/data/notification_scheduler.dart';
import 'package:meowscope/features/notifications/data/notifier.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';
import 'package:meowscope/features/notifications/domain/reminder_plan.dart';

import '../../helpers/recording_notifier.dart';
import '../../helpers/test_db.dart';

void main() {
  MedicationPlanItem item(
    String id, {
    String time = '08:00',
    String? dose = '1錠',
    bool enabled = true,
  }) => MedicationPlanItem(
    id: id,
    catName: 'ミケ',
    name: '○○錠',
    dose: dose,
    timeOfDay: time,
    enabled: enabled,
  );

  List<PlannedNotification> plan(
    List<MedicationPlanItem> items, {
    DateTime? now,
    NotificationSettings settings = const NotificationSettings(),
    bool android = true,
  }) => planMedications(
    schedules: items,
    settings: settings,
    now: now ?? DateTime(2026, 11, 7, 12),
    android: android,
  );

  group('UT-MD-03 時刻の形（HH:mm）', () {
    test('境界値：00:00・23:59 は読め、24:00・8:00・08:60・空は読まない', () {
      expect(parseTimeOfDay('00:00'), (hour: 0, minute: 0));
      expect(parseTimeOfDay('23:59'), (hour: 23, minute: 59));
      for (final bad in ['24:00', '8:00', '08:60', '', '08:00:00']) {
        expect(parseTimeOfDay(bad), isNull, reason: bad);
      }
    });

    test('時と分を2けたにする', () {
      expect(formatTimeOfDay(8, 5), '08:05');
      expect(formatTimeOfDay(23, 59), '23:59');
    });
  });

  group('UT-MD-04 お薬の時間の予約（F-NT-01、BR-06）', () {
    test('予定ごとに毎日の繰り返しで予約する。同じ薬の1日2回は2つの予約になる', () {
      final p = plan([item('m1'), item('m2', time: '20:00')]);
      expect(p, hasLength(2));
      expect(p.every((x) => x.daily), isTrue);
      expect(p.first.notification.id, notificationId('medication', 'm1'));
      expect(p.first.notification.title, 'ミケのお薬の時間です');
      expect(p.first.notification.body, '○○錠 1錠');
      expect(p.first.notification.payload, '/');
    });

    test('量がなければ、2行目は薬の名前だけ', () {
      expect(plan([item('m1', dose: null)]).single.notification.body, '○○錠');
    });

    test('境界値：今日の時刻がまだ（1分後）なら今日、ちょうど今・過ぎていれば明日', () {
      final now = DateTime(2026, 11, 7, 7, 59);
      expect(plan([item('m1')], now: now).single.at, DateTime(2026, 11, 7, 8));
      expect(
        plan([item('m1')], now: DateTime(2026, 11, 7, 8)).single.at,
        DateTime(2026, 11, 8, 8),
      );
      expect(
        plan([item('m1')], now: DateTime(2026, 11, 7, 12)).single.at,
        DateTime(2026, 11, 8, 8),
      );
    });

    test('月末の次の日は翌月の1日', () {
      expect(
        plan([item('m1')], now: DateTime(2026, 11, 30, 9)).single.at,
        DateTime(2026, 12, 1, 8),
      );
    });

    test('オフの予定と、形の壊れた時刻の予定は予約しない', () {
      expect(
        plan([item('m1', enabled: false), item('m2', time: '25:00')]),
        isEmpty,
      );
    });

    test('通知の設定でお薬の時間がオフなら予約しない', () {
      expect(
        plan(
          [item('m1')],
          settings: const NotificationSettings(
            enabled: {NotificationKind.medication: false},
          ),
        ),
        isEmpty,
      );
    });

    test('Windows では予約しない（BR-09）', () {
      expect(plan([item('m1')], android: false), isEmpty);
    });
  });

  group('UT-MD-05 毎日の繰り返しの予約の置き換え', () {
    late AppDatabase db;
    late RecordingNotifier notifier;
    late DateTime clock;
    late NotificationScheduler scheduler;

    setUp(() {
      db = memoryDatabase();
      notifier = RecordingNotifier();
      clock = DateTime(2026, 11, 7, 7);
      scheduler = NotificationScheduler(db, notifier, clock: () => clock);
    });
    tearDown(() => db.close());

    PlannedNotification planned(String id) => PlannedNotification(
      AppNotification(id: notificationId('medication', id), title: id),
      DateTime(2026, 11, 7, 8),
      daily: true,
    );

    test('繰り返しで端末に予約する', () async {
      await scheduler.replace('medication', [planned('m1')]);
      expect(notifier.daily, {notificationId('medication', 'm1')});
    });

    test('最初の時刻を過ぎていても、予定から外れたら取り消す（次の日にまた出るため）', () async {
      await scheduler.replace('medication', [planned('m1')]);
      clock = DateTime(2026, 11, 9, 12);
      final next = NotificationScheduler(db, notifier, clock: () => clock);
      await next.replace('medication', const []);
      expect(notifier.cancelled, [notificationId('medication', 'm1')]);
      expect(notifier.scheduled, isEmpty);
    });

    test('次の日に計算し直して最初の時刻が変わっても、端末の状態は書き直さない', () async {
      await scheduler.replace('medication', [planned('m1')]);
      var writes = 0;
      final sub = db.select(db.appStates).watch().listen((_) => writes++);
      await pumpEventQueue();
      final before = writes;
      await scheduler.replace('medication', [
        PlannedNotification(
          AppNotification(id: notificationId('medication', 'm1'), title: 'm1'),
          DateTime(2026, 11, 8, 8),
          daily: true,
        ),
      ]);
      await pumpEventQueue();
      expect(writes, before);
      await sub.cancel();
    });
  });

  test('UT-MD-06 Windows の画面の中の予約も、毎日の繰り返しなら次の日の分を予約し直す', () async {
    final notifier = InAppNotifier();
    final shown = <AppNotification>[];
    final sub = notifier.stream.listen(shown.add);
    // 1日前の時刻から少し後：最初はすぐに出て、次の日の分（すぐ後）もまた出る
    final at = DateTime.now()
        .subtract(const Duration(days: 1))
        .add(const Duration(milliseconds: 100));
    await notifier.schedule(
      const AppNotification(id: 1, title: 'ミケのお薬の時間です'),
      at,
      daily: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(shown, hasLength(2));
    await notifier.cancel(1);
    await sub.cancel();
    await notifier.close();
  });
}
