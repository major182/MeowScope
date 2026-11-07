import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/features/sync/presentation/sync_controller.dart';
import 'package:meowscope/features/notifications/data/family_alerts.dart';
import 'package:meowscope/features/notifications/domain/family_plan.dart';
import 'package:meowscope/features/notifications/domain/notification_settings.dart';
import 'package:meowscope/features/notifications/domain/reminder_plan.dart';
import 'package:meowscope/features/sync/data/sync_engine.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/recording_notifier.dart';
import '../../helpers/test_db.dart';

void main() {
  FamilyRecord rec(
    String id, {
    String author = 'u2',
    String name = 'なつ',
    String cat = 'ミケ',
    String type = 'ご飯',
  }) => FamilyRecord(
    id: id,
    authorKey: author,
    authorName: name,
    catName: cat,
    typeName: type,
  );

  group('UT-FN-01 家族の記録の通知の文（画面設計書 4章）', () {
    test('1件：だれが・どの猫の・何を記録したか。メモなどの2行目はない', () {
      final n = familyNotifications([rec('r1')]).single;
      expect(n.title, 'なつさんがミケのご飯を記録しました');
      expect(n.body, isNull);
      expect(n.payload, '/');
      expect(n.id, notificationId('family', 'r1'));
    });

    test('同じ人の2件（境界値）はまとめて件数にする', () {
      final n = familyNotifications([
        rec('r1'),
        rec('r2', cat: 'タマ', type: 'トイレ'),
      ]).single;
      expect(n.title, 'なつさんが2件記録しました');
    });

    test('記録した人ごとに分ける', () {
      final list = familyNotifications([
        rec('r1'),
        rec('r2', author: 'u3', name: 'はる'),
        rec('r3'),
      ]);
      expect(
        [for (final n in list) n.title],
        ['なつさんが2件記録しました', 'はるさんがミケのご飯を記録しました'],
      );
    });

    test('記録がなければ出さない', () {
      expect(familyNotifications(const []), isEmpty);
    });
  });

  group('UT-FN-02 受け取った家族の記録を知らせる（BR-08・09）', () {
    late AppDatabase db;
    late RecordingNotifier notifier;
    late FamilyAlerts alerts;

    setUp(() async {
      db = memoryDatabase();
      notifier = RecordingNotifier();
      alerts = FamilyAlerts(db, notifier);
      await addHousehold(db, 'h1');
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await addCat(
        db,
        id: 'c2',
        householdId: 'h1',
        name: 'クロ',
        status: 'farewell',
      );
      await addCat(
        db,
        id: 'c3',
        householdId: 'h1',
        name: 'シロ',
        deletedAt: testTime,
      );
      await db
          .into(db.recordTypes)
          .insert(
            RecordTypesCompanion.insert(
              id: 't1',
              createdAt: testTime,
              updatedAt: testTime,
              householdId: 'h1',
              name: 'ご飯',
              kind: 'food',
            ),
          );
    });
    tearDown(() => db.close());

    ReceivedRecord received(
      String id, {
      String catId = 'c1',
      String typeId = 't1',
      String? authorId = 'u2',
      String authorName = 'なつ',
    }) => ReceivedRecord(
      id: id,
      catId: catId,
      recordTypeId: typeId,
      recordedAt: testTime,
      authorId: authorId,
      authorName: authorName,
    );

    test('Android でオンなら、猫と項目の名前を入れて知らせる', () async {
      final shown = await alerts.notify(
        [received('r1')],
        settings: const NotificationSettings(),
        android: true,
      );
      expect(shown, 1);
      expect(notifier.shown.single.title, 'なつさんがミケのご飯を記録しました');
    });

    test('お別れ・削除した猫と、知らない猫・項目の記録は知らせない', () async {
      final shown = await alerts.notify(
        [
          received('r1', catId: 'c2'),
          received('r2', catId: 'c3'),
          received('r3', typeId: 'unknown'),
          received('r4', catId: 'unknown'),
        ],
        settings: const NotificationSettings(),
        android: true,
      );
      expect(shown, 0);
      expect(notifier.shown, isEmpty);
    });

    test('退会した人（authorId なし）は表示名で分ける', () async {
      await alerts.notify(
        [
          received('r1', authorId: null),
          received('r2', authorId: null),
          received('r3', authorId: null, authorName: 'はる'),
        ],
        settings: const NotificationSettings(),
        android: true,
      );
      expect(
        [for (final n in notifier.shown) n.title],
        ['なつさんが2件記録しました', 'はるさんがミケのご飯を記録しました'],
      );
    });

    test('設定でオフなら出さない', () async {
      final shown = await alerts.notify(
        [received('r1')],
        settings: const NotificationSettings(
          enabled: {NotificationKind.family: false},
        ),
        android: true,
      );
      expect(shown, 0);
      expect(notifier.shown, isEmpty);
    });

    test('Windows では出さない（BR-09）', () async {
      final shown = await alerts.notify(
        [received('r1')],
        settings: const NotificationSettings(),
        android: false,
      );
      expect(shown, 0);
      expect(notifier.shown, isEmpty);
    });

    test('UT-FN-03 同期が成功したら、受け取った家族の記録を知らせる（結合：同期の管理→通知）', () async {
      final server = FakeServer();
      final tokens = MemoryTokenStore()
        ..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
      await db.batch(
        (b) => b.insertAll(db.appStates, [
          AppStatesCompanion.insert(key: 'session.userId', value: 'u1'),
          AppStatesCompanion.insert(key: 'session.userName', value: 'はる'),
          AppStatesCompanion.insert(key: SyncKeys.lastSeq('u1'), value: '5'),
        ]),
      );
      server.on(
        'POST',
        '/sync',
        (r) => const FakeResponse(200, {
          'results': <Object>[],
          'changes': [
            {
              'table': 'records',
              'id': 'r1',
              'seq': 6,
              'updatedAt': '2026-11-03T01:00:00Z',
              'deletedAt': null,
              'data': {
                'catId': 'c1',
                'recordTypeId': 't1',
                'recordedAt': '2026-11-03T00:30:00Z',
                'authorId': 'u2',
                'authorName': 'なつ',
              },
            },
          ],
          'nextSeq': 6,
          'hasMore': false,
          'fullResyncRequired': false,
        }),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(fakeApiClient(server, tokens)),
          notifierProvider.overrideWithValue(notifier),
        ],
      );
      addTearDown(container.dispose);
      container.listen(authUserProvider, (_, _) {});
      container.listen(notificationSettingsProvider, (_, _) {});
      await container.read(authUserProvider.future);

      await container.read(syncControllerProvider.notifier).sync();

      expect(container.read(syncControllerProvider).error, isNull);
      expect(notifier.shown.single.title, 'なつさんがミケのご飯を記録しました');
    });

    test('記録がなければ何もしない', () async {
      expect(
        await alerts.notify(
          const [],
          settings: const NotificationSettings(),
          android: true,
        ),
        0,
      );
    });
  });
}
