import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/api/api_error.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/features/notifications/data/anomaly_alerts.dart';
import 'package:meowscope/features/notifications/data/notifier.dart';
import 'package:meowscope/features/notifications/domain/anomaly.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';
import 'package:meowscope/features/notifications/presentation/notification_runner.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/sync/presentation/sync_controller.dart';

import '../../helpers/recording_notifier.dart';
import '../../helpers/test_db.dart';

void main() {
  final now = DateTime(2026, 11, 6, 12);

  Anomaly anomaly({
    String kind = 'food',
    AnomalyDirection direction = AnomalyDirection.low,
    DateTime? day,
    num observed = 1,
    num usual = 3.2,
  }) => Anomaly(
    catId: 'c1',
    catName: 'ミケ',
    kind: kind,
    direction: direction,
    day: day ?? DateTime(2026, 11, 5),
    observed: observed,
    usual: usual,
  );

  group('UT-AN-07 いつもとの差の通知の文（画面設計書 4章）', () {
    test('回数・少なめ・きのう・統計：ふだんは四捨五入して「くらい」', () {
      final n = anomalyNotification(
        anomaly(),
        method: AnomalyMethod.statistical,
        now: now,
      );
      expect(n.title, 'ミケのご飯がいつもより少なめです');
      expect(n.body, 'きのう 1回（ふだん 3回くらい）');
      // 押すと、その猫と項目の統計を開く
      expect(n.payload, '/stats?cat=c1&kind=food');
    });

    test('回数・多め・きょう', () {
      final n = anomalyNotification(
        anomaly(
          kind: 'vomit',
          direction: AnomalyDirection.high,
          day: DateTime(2026, 11, 6),
          observed: 3,
          usual: 0.4,
        ),
        method: AnomalyMethod.statistical,
        now: now,
      );
      expect(n.title, 'ミケの吐いたがいつもより多めです');
      expect(n.body, 'きょう 3回（ふだん 0回くらい）');
    });

    test('しきい値の方式では、かっこを下限・上限にする', () {
      final low = anomalyNotification(
        anomaly(observed: 0, usual: 1),
        method: AnomalyMethod.threshold,
        now: now,
      );
      expect(low.body, 'きのう 0回（下限 1回）');
      final high = anomalyNotification(
        anomaly(direction: AnomalyDirection.high, observed: 6, usual: 5),
        method: AnomalyMethod.threshold,
        now: now,
      );
      expect(high.body, 'きのう 6回（上限 5回）');
    });

    test('体重の増減。2行目はない', () {
      final up = anomalyNotification(
        anomaly(kind: 'weight', direction: AnomalyDirection.high, observed: 6),
        method: AnomalyMethod.statistical,
        now: now,
      );
      expect(up.title, 'ミケの体重がいつもより 6% 増えています');
      expect(up.body, isNull);
      expect(up.payload, '/stats?cat=c1&kind=weight');
      final down = anomalyNotification(
        anomaly(kind: 'weight', observed: 7),
        method: AnomalyMethod.statistical,
        now: now,
      );
      expect(down.title, 'ミケの体重がいつもより 7% 減っています');
    });

    test('同じ内容は同じ id、日が違えば別の id', () {
      AppNotification n(DateTime day) => anomalyNotification(
        anomaly(day: day),
        method: AnomalyMethod.statistical,
        now: now,
      );
      expect(n(DateTime(2026, 11, 5)).id, n(DateTime(2026, 11, 5)).id);
      expect(n(DateTime(2026, 11, 5)).id, isNot(n(DateTime(2026, 11, 4)).id));
    });
  });

  group('UT-AN-08 判定して知らせる（BR-12）', () {
    late AppDatabase db;
    late RecordingNotifier notifier;
    late DateTime clock;
    late AnomalyAlerts alerts;

    setUp(() async {
      db = memoryDatabase();
      notifier = RecordingNotifier();
      clock = now;
      alerts = AnomalyAlerts(
        db,
        RecordRepository(db),
        notifier,
        clock: () => clock,
      );
      await addHousehold(db, 'h1');
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await addCat(
        db,
        id: 'c2',
        householdId: 'h1',
        name: 'タマ',
        status: 'farewell',
      );
      await db
          .into(db.recordTypes)
          .insert(
            RecordTypesCompanion.insert(
              id: 'food',
              createdAt: testTime,
              updatedAt: testTime,
              householdId: 'h1',
              name: 'ご飯',
              kind: 'food',
            ),
          );
      // ミケもタマも、10日前から2日前まで毎日3回、きのうは1回
      var n = 0;
      for (final cat in ['c1', 'c2']) {
        for (var d = 2; d <= 10; d++) {
          for (var i = 0; i < 3; i++) {
            await addFood(db, 'r${n++}', cat, DateTime(2026, 11, 6 - d, 8 + i));
          }
        }
        await addFood(db, 'r${n++}', cat, DateTime(2026, 11, 5, 8));
      }
    });
    tearDown(() => db.close());

    Future<int> check({
      NotificationSettings settings = const NotificationSettings(),
      bool android = true,
    }) => alerts.check(householdId: 'h1', settings: settings, android: android);

    test('外れ値を知らせ、知らせた日を残す。お別れの猫は判定しない', () async {
      expect(await check(), 1);
      expect(notifier.shown.single.title, 'ミケのご飯がいつもより少なめです');
      expect(notifier.shown.single.body, 'きのう 1回（ふだん 3回くらい）');
      final row =
          await (db.select(db.appStates)
                ..where((s) => s.key.equals(AnomalyAlerts.key('c1', 'food'))))
              .getSingle();
      expect(row.value, '2026-11-6');
    });

    test('同じ日にもう一度判定しても知らせない。次の日なら、同じ猫・種類でも知らせる', () async {
      await check();
      clock = DateTime(2026, 11, 6, 20);
      expect(await check(), 0);
      expect(notifier.shown, hasLength(1));
      // 次の日：きのう（11/6）も1回だけ
      await addFood(db, 'x', 'c1', DateTime(2026, 11, 6, 8));
      clock = DateTime(2026, 11, 7, 9);
      expect(await check(), 1);
      expect(notifier.shown, hasLength(2));
    });

    test('いつもとの差がオフなら知らせない', () async {
      final off = const NotificationSettings().toggled(
        NotificationKind.anomaly,
        false,
      );
      expect(await check(settings: off), 0);
      expect(notifier.shown, isEmpty);
    });

    test('Windows でも知らせる（BR-09）', () async {
      expect(await check(android: false), 1);
    });

    test('外れ値がなければ知らせない', () async {
      await addFood(db, 'y1', 'c1', DateTime(2026, 11, 5, 12));
      await addFood(db, 'y2', 'c1', DateTime(2026, 11, 5, 18));
      expect(await check(), 0);
    });
  });

  group('UT-AN-09 同期の成功だけを判定のきっかけにする（BR-05）', () {
    const running = SyncState(running: true);
    test('実行中から成功に変わったとき', () {
      expect(syncJustSucceeded(running, const SyncState()), isTrue);
    });
    test('失敗・ログインの期限切れ・実行中でなかったときは、きっかけにしない', () {
      expect(
        syncJustSucceeded(running, const SyncState(error: ApiError(status: 0))),
        isFalse,
      );
      expect(
        syncJustSucceeded(running, const SyncState(needsLogin: true)),
        isFalse,
      );
      expect(syncJustSucceeded(null, const SyncState()), isFalse);
      expect(syncJustSucceeded(const SyncState(), const SyncState()), isFalse);
      expect(syncJustSucceeded(running, running), isFalse);
    });
  });
}

Future<void> addFood(AppDatabase db, String id, String catId, DateTime at) => db
    .into(db.records)
    .insert(
      RecordsCompanion.insert(
        id: id,
        createdAt: testTime,
        updatedAt: testTime,
        catId: catId,
        recordTypeId: 'food',
        recordedAt: at.toUtc(),
        authorName: 'はる',
        authorId: const Value('u1'),
      ),
    );
