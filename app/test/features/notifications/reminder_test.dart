import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/notifications/data/notification_scheduler.dart';
import 'package:meowscope/features/notifications/data/notifier.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';
import 'package:meowscope/features/notifications/domain/reminder_plan.dart';
import 'package:meowscope/features/records/data/record_repository.dart';

import '../../helpers/recording_notifier.dart';
import '../../helpers/test_db.dart';

void main() {
  final now = DateTime(2026, 11, 6, 12);
  const mike = ReminderCat(id: 'c1', name: 'ミケ');
  const tama = ReminderCat(id: 'c2', name: 'タマ');

  List<PlannedNotification> plan({
    Map<String, DateTime>? last,
    NotificationSettings settings = const NotificationSettings(),
  }) => planReminders(
    cats: const [mike, tama],
    lastRecordAt: last ?? {'c1': DateTime(2026, 11, 6, 8)},
    settings: settings,
    now: now,
  );

  group('UT-RM-01 記録忘れの予約（BR-13）', () {
    test('猫ごとに、最後の記録から n 時間後に予約する。記録のない猫は予約しない', () {
      final p = plan();
      expect(p, hasLength(1));
      expect(p.single.at, DateTime(2026, 11, 6, 18));
      expect(p.single.notification.title, 'ミケの記録が10時間ありません');
      expect(p.single.notification.payload, '/');
    });

    test('n は設定の時間を使う', () {
      final p = plan(
        last: {'c1': DateTime(2026, 11, 6, 10)},
        settings: const NotificationSettings(reminderHours: 3),
      );
      expect(p.single.at, DateTime(2026, 11, 6, 13));
      expect(p.single.notification.title, 'ミケの記録が3時間ありません');
    });

    test('Windows では記録忘れを予約しない（ふだんの記録は Android で行うため。BR-09）', () {
      final windows = planReminders(
        cats: const [mike],
        lastRecordAt: {'c1': DateTime(2026, 11, 6, 8)},
        settings: const NotificationSettings(),
        now: now,
        android: false,
      );
      expect(windows, isEmpty);
      expect(NotificationKind.forDevice(android: false), [
        NotificationKind.anomaly,
        NotificationKind.birthday,
      ]);
      expect(
        NotificationKind.forDevice(android: true),
        NotificationKind.values,
      );
    });

    test('記録忘れがオフなら予約しない', () {
      final off = const NotificationSettings().toggled(
        NotificationKind.reminder,
        false,
      );
      expect(plan(settings: off), isEmpty);
    });
  });

  test('UT-RM-02 境界値：知らせる時刻が今ちょうど・過ぎていれば予約せず、1ミリ秒でも先なら予約する', () {
    final exactly = now.subtract(const Duration(hours: 10));
    expect(plan(last: {'c1': exactly}), isEmpty);
    expect(
      plan(last: {'c1': exactly.subtract(const Duration(hours: 1))}),
      isEmpty,
    );
    expect(
      plan(last: {'c1': exactly.add(const Duration(milliseconds: 1))}),
      hasLength(1),
    );
  });

  test('UT-RM-03 通知の id：同じ種類と対象ならいつも同じ値、違えば違う値。0 以上の 32 ビットに収まる', () {
    final a = notificationId('reminder', 'c1');
    expect(notificationId('reminder', 'c1'), a);
    expect(notificationId('reminder', 'c2'), isNot(a));
    expect(notificationId('birthday', 'c1'), isNot(a));
    expect(a, inInclusiveRange(0, 0x7fffffff));
  });

  group('UT-RM-04 予約の置き換え', () {
    late AppDatabase db;
    late RecordingNotifier notifier;
    late NotificationScheduler scheduler;
    var clock = DateTime(2026, 11, 6, 12);
    setUp(() {
      db = memoryDatabase();
      notifier = RecordingNotifier();
      clock = DateTime(2026, 11, 6, 12);
      scheduler = NotificationScheduler(db, notifier, clock: () => clock);
    });
    tearDown(() => db.close());

    PlannedNotification planned(String catId) => PlannedNotification(
      AppNotification(id: notificationId('reminder', catId), title: catId),
      DateTime(2026, 11, 6, 18),
    );

    test('時刻を過ぎた予約（もう知らせたもの）は、予約から外れても取り消さない（出ている通知を消さないため）', () async {
      await scheduler.replace('reminder', [planned('c1')]);
      clock = DateTime(2026, 11, 6, 18, 1);
      await scheduler.replace('reminder', const []);
      expect(notifier.cancelled, isEmpty);

      // 境界値：時刻ちょうどは知らせ済みとして扱い、1ミリ秒前ならまだ取り消す
      await scheduler.replace('reminder', [planned('c1')]);
      clock = DateTime(2026, 11, 6, 18);
      await scheduler.replace('reminder', const []);
      expect(notifier.cancelled, isEmpty);
      await scheduler.replace('reminder', [planned('c1')]);
      clock = DateTime(2026, 11, 6, 17, 59, 59, 999);
      await scheduler.replace('reminder', const []);
      expect(notifier.cancelled, [notificationId('reminder', 'c1')]);
    });

    test('新しい予約にない前の予約は取り消し、残るものは置き換える。次に起動したときも前の予約を覚えている', () async {
      await scheduler.replace('reminder', [planned('c1'), planned('c2')]);
      expect(notifier.scheduled, hasLength(2));

      // 次に起動したとき（覚えている予約は端末の状態から読む）
      final next = NotificationScheduler(db, notifier, clock: () => clock);
      await next.replace('reminder', [planned('c2')]);
      expect(notifier.cancelled, [notificationId('reminder', 'c1')]);
      expect(notifier.scheduled.keys, [notificationId('reminder', 'c2')]);

      await next.clear('reminder');
      expect(notifier.scheduled, isEmpty);
    });

    test('予約の id が変わらなければ端末の状態を書かない（通知の設定の見張りが流れ直して、予約を繰り返さないため）', () async {
      var writes = 0;
      final sub = db.select(db.appStates).watch().listen((_) => writes++);
      await scheduler.replace('reminder', [planned('c1')]);
      await pumpEventQueue();
      final afterFirst = writes;

      await scheduler.replace('reminder', [planned('c1')]);
      await pumpEventQueue();
      expect(writes, afterFirst);
      await sub.cancel();
    });

    test('異常系：覚えている予約が壊れていても、新しい予約を置ける', () async {
      await db
          .into(db.appStates)
          .insert(
            AppStatesCompanion.insert(
              key: NotificationScheduler.key('reminder'),
              value: '壊れた',
            ),
          );
      await scheduler.replace('reminder', [planned('c1')]);
      expect(notifier.scheduled, hasLength(1));
    });
  });

  group('UT-RM-05 猫ごとの最後の記録', () {
    late AppDatabase db;
    setUp(() async {
      db = memoryDatabase();
      await addHousehold(db, 'h1');
      await addHousehold(db, 'h2');
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
      await addCat(db, id: 'c3', householdId: 'h2', name: 'よそ');
      await RecordRepository(db).addStandardTypes('h1');
    });
    tearDown(() => db.close());

    Future<void> record(
      String id,
      String catId,
      DateTime at, {
      bool deleted = false,
    }) async {
      final type = await (db.select(db.recordTypes)..limit(1)).getSingle();
      await db
          .into(db.records)
          .insert(
            RecordsCompanion.insert(
              id: id,
              createdAt: testTime,
              updatedAt: testTime,
              deletedAt: Value(deleted ? testTime : null),
              catId: catId,
              recordTypeId: type.id,
              recordedAt: at,
              authorName: 'なつ',
            ),
          );
    }

    test('家族の記録を含めて猫ごとの最新を返し、削除した記録・削除した猫・ほかのおうちは除く', () async {
      await record('r1', 'c1', DateTime.utc(2026, 11, 6, 1));
      await record('r2', 'c1', DateTime.utc(2026, 11, 6, 3));
      await record('r3', 'c1', DateTime.utc(2026, 11, 6, 5), deleted: true);
      await record('r4', 'c2', DateTime.utc(2026, 11, 5, 9));
      await record('r5', 'c3', DateTime.utc(2026, 11, 6, 9));
      await (db.update(db.cats)..where((c) => c.id.equals('c2'))).write(
        CatsCompanion(deletedAt: Value(testTime)),
      );

      final last = await RecordRepository(db).watchLastRecordTimes('h1').first;
      expect(last.keys, ['c1']);
      expect(last['c1']!.toUtc(), DateTime.utc(2026, 11, 6, 3));
    });
  });

  test('UT-RM-06 Windows：アプリの起動中は予約の時刻に画面の中で知らせ、取り消したら知らせない', () async {
    final notifier = InAppNotifier();
    final shown = <AppNotification>[];
    final sub = notifier.stream.listen(shown.add);
    final soon = DateTime.now().add(const Duration(milliseconds: 50));

    await notifier.schedule(const AppNotification(id: 1, title: 'ミケ'), soon);
    await notifier.schedule(const AppNotification(id: 2, title: 'タマ'), soon);
    await notifier.cancel(2);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(shown.map((n) => n.title), ['ミケ']);
    await sub.cancel();
    await notifier.close();
  });
}
