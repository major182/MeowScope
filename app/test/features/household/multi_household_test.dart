import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/db/household_choice.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/account_repository.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/medication/data/medication_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/main.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

/// 1人が2つ以上のおうちに入るとき（F-SH-09、BR-39）
void main() {
  late AppDatabase db;
  late FakeServer server;
  late MemoryTokenStore tokens;

  Future<void> household(String id, String name, {DateTime? deletedAt}) => db
      .into(db.households)
      .insert(
        HouseholdsCompanion.insert(
          id: id,
          createdAt: testTime,
          updatedAt: testTime,
          name: name,
          deletedAt: Value(deletedAt),
        ),
      );

  Future<void> member(
    String id,
    String householdId,
    String userId, {
    required DateTime joinedAt,
    DateTime? deletedAt,
  }) => db
      .into(db.householdMembers)
      .insert(
        HouseholdMembersCompanion.insert(
          id: id,
          createdAt: joinedAt,
          updatedAt: joinedAt,
          householdId: householdId,
          userId: Value(userId),
          displayName: const Value('はる'),
          deletedAt: Value(deletedAt),
        ),
      );

  Future<Map<String, String>> states() async => {
    for (final s in await db.select(db.appStates).get()) s.key: s.value,
  };

  Future<void> setCurrent(String? householdId) async {
    await (db.delete(
      db.appStates,
    )..where((s) => s.key.equals('session.householdId'))).go();
    if (householdId != null) {
      await db
          .into(db.appStates)
          .insert(
            AppStatesCompanion.insert(
              key: 'session.householdId',
              value: householdId,
            ),
          );
    }
  }

  setUp(() async {
    db = memoryDatabase();
    server = FakeServer()
      ..on(
        'POST',
        '/sync',
        (r) => const FakeResponse(200, {
          'results': [],
          'changes': [],
          'nextSeq': 1,
          'hasMore': false,
          'fullResyncRequired': false,
        }),
      );
    tokens = MemoryTokenStore()
      ..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    // はるは h1（先に入った）と h2 に入っている。今のおうちは h1
    await household('h1', 'みけ家');
    await household('h2', 'たま家');
    await member('m1', 'h1', 'u1', joinedAt: testTime);
    await member(
      'm2',
      'h2',
      'u1',
      joinedAt: testTime.add(const Duration(days: 1)),
    );
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h2', name: 'タマ');
    await db.batch(
      (b) => b.insertAll(db.appStates, [
        AppStatesCompanion.insert(key: 'session.userId', value: 'u1'),
        AppStatesCompanion.insert(key: 'session.userName', value: 'はる'),
        AppStatesCompanion.insert(key: 'session.householdId', value: 'h1'),
        AppStatesCompanion.insert(key: 'household.u1', value: 'h1'),
      ]),
    );
  });
  tearDown(() => db.close());

  group('入っているおうち', () {
    test('UT-MH-01 入った順に並ぶ。抜けたおうち・消えたおうち・ほかの人だけのおうちは出さない', () async {
      await household('h3', '抜けた家');
      await member(
        'm3',
        'h3',
        'u1',
        joinedAt: testTime,
        deletedAt: testTime.add(const Duration(days: 2)),
      );
      await household('h4', '消えた家', deletedAt: testTime);
      await member('m4', 'h4', 'u1', joinedAt: testTime);
      await household('h5', 'ほかの家');
      await member('m5', 'h5', 'u2', joinedAt: testTime);

      final ids = [for (final h in await myHouseholds(db, 'u1').get()) h.id];
      expect(ids, ['h1', 'h2']);
    });

    test('UT-MH-02 メンバーの行がまだない今のおうち（招待で入った直後）も、最後に出す', () async {
      await household('h3', '');
      await setCurrent('h3');

      final ids = [for (final h in await myHouseholds(db, 'u1').get()) h.id];
      expect(ids, ['h1', 'h2', 'h3']);
    });

    test('UT-MH-03 一覧は、顔ぶれと名前が変わったときだけ流れる（ほかの設定の変更では流れない）', () async {
      final repo = HouseholdRepository(db, RecordRepository(db));
      final seen = <List<String>>[];
      final sub = repo
          .watchHouseholds('u1')
          .listen((l) => seen.add([for (final h in l) h.name]));
      await pumpEventQueue();
      await db
          .into(db.appStates)
          .insert(AppStatesCompanion.insert(key: 'sync.x', value: '1'));
      await pumpEventQueue();
      await (db.update(db.households)..where((h) => h.id.equals('h2'))).write(
        const HouseholdsCompanion(name: Value('とら家')),
      );
      await pumpEventQueue();
      await sub.cancel();

      expect(seen, [
        ['みけ家', 'たま家'],
        ['みけ家', 'とら家'],
      ]);
    });
  });

  group('切り替えと選び直し', () {
    test('UT-MH-04 入っているおうちに切り替えると、今のおうちと最後に選んだおうちが変わる', () async {
      final repo = HouseholdRepository(db, RecordRepository(db));

      expect(
        await repo.switchHousehold(userId: 'u1', householdId: 'h2'),
        isTrue,
      );
      final s = await states();
      expect(s['session.householdId'], 'h2');
      expect(s['household.u1'], 'h2');
      expect((await repo.watchSession().first)!.householdId, 'h2');
    });

    test('UT-MH-05 異常系：入っていないおうちには切り替えない', () async {
      await household('h9', 'ほかの家');
      final repo = HouseholdRepository(db, RecordRepository(db));

      expect(
        await repo.switchHousehold(userId: 'u1', householdId: 'h9'),
        isFalse,
      );
      expect(
        await repo.switchHousehold(userId: 'u1', householdId: 'none'),
        isFalse,
      );
      expect((await states())['session.householdId'], 'h1');
    });

    test('UT-MH-06 今のおうちがあれば変えない。なければ入った順の最初を選ぶ。どこにも入っていなければ選ばない', () async {
      expect(await chooseHouseholdIfNone(db, 'u1'), 'h1');

      await setCurrent(null);
      await (db.update(db.householdMembers)..where((m) => m.id.equals('m1')))
          .write(HouseholdMembersCompanion(deletedAt: Value(testTime)));
      expect(await chooseHouseholdIfNone(db, 'u1'), 'h2');
      expect((await states())['household.u1'], 'h2');

      await setCurrent(null);
      await (db.update(db.householdMembers)..where((m) => m.id.equals('m2')))
          .write(HouseholdMembersCompanion(deletedAt: Value(testTime)));
      expect(await chooseHouseholdIfNone(db, 'u1'), isNull);
      expect((await states())['session.householdId'], isNull);
    });

    test('UT-MH-07 今のおうちを抜けると、残りのおうちが今のおうちになる', () async {
      server.on(
        'POST',
        '/households/h1/leave',
        (r) => const FakeResponse(200, {'householdDeleted': false}),
      );
      final repo = AccountRepository(db, fakeApiClient(server, tokens), tokens);

      await repo.leaveHousehold(
        userId: 'u1',
        householdId: 'h1',
        keepRecords: true,
      );

      final s = await states();
      expect(s['session.householdId'], 'h2');
      expect(s['household.u1'], 'h2');
      expect([for (final c in await db.select(db.cats).get()) c.id], ['c2']);
    });
  });

  group('すべてのおうちの通知の材料', () {
    test('UT-MH-17 おうちの ID は、ログインの状態が届く前の空の一覧を流さず、名前を変えても途切れない', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final seen = <List<String>?>[];
      final sub = container.listen(
        householdIdsProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);
      for (var i = 0; i < 20 && seen.lastOrNull == null; i++) {
        await pumpEventQueue();
      }
      expect(seen.last, ['h1', 'h2']);
      // 空の一覧（おうちなし）として流れたことはない。そろうまでは null
      expect(seen.where((ids) => ids != null && ids.isEmpty), isEmpty);

      final before = seen.length;
      await (db.update(db.households)..where((h) => h.id.equals('h2'))).write(
        const HouseholdsCompanion(name: Value('とら家')),
      );
      await pumpEventQueue();
      expect(seen.skip(before), everyElement(['h1', 'h2']));
    });

    test('UT-MH-08 猫・最後の記録・お薬の予定を、いくつかのおうちについてまとめて読む', () async {
      final records = RecordRepository(db);
      final cats = await records.watchActiveCatsIn(['h1', 'h2']).first;
      expect([for (final c in cats) c.id], ['c1', 'c2']);
      expect(await records.watchActiveCatsIn(['h2']).first, hasLength(1));

      final food = await db
          .into(db.recordTypes)
          .insertReturning(
            RecordTypesCompanion.insert(
              id: 't2',
              createdAt: testTime,
              updatedAt: testTime,
              householdId: 'h2',
              name: 'ご飯',
              icon: const Value('food'),
              kind: 'food',
              sortOrder: const Value(0),
            ),
          );
      await db
          .into(db.records)
          .insert(
            RecordsCompanion.insert(
              id: 'r1',
              createdAt: testTime,
              updatedAt: testTime,
              catId: 'c2',
              recordTypeId: food.id,
              recordedAt: testTime,
              authorName: 'はる',
            ),
          );
      final last = await records.watchLastRecordTimesIn(['h1', 'h2']).first;
      expect(last.keys, ['c2']);

      await db
          .into(db.medicationSchedules)
          .insert(
            MedicationSchedulesCompanion.insert(
              id: 'ms1',
              createdAt: testTime,
              updatedAt: testTime,
              householdId: 'h2',
              catId: 'c2',
              name: '目薬',
              timeOfDay: '08:00',
            ),
          );
      final meds = MedicationRepository(db);
      expect(await meds.watchSchedulesIn(['h1', 'h2']).first, hasLength(1));
      expect(await meds.watchSchedulesIn(['h1']).first, isEmpty);
    });
  });

  group('画面（S-42）', () {
    Future<void> start(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tokenStoreProvider.overrideWithValue(tokens),
            apiClientProvider.overrideWithValue(fakeApiClient(server, tokens)),
          ],
          child: const MeowScopeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('設定').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('おうちの管理'));
      await tester.pumpAndSettle();
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }

    testWidgets('UT-MH-09 おうちが2つ以上なら切り替えを出し、押したおうちに切り替わる', (tester) async {
      await start(tester);

      expect(find.text('おうちを切り替える'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'みけ家'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'たま家'));
      await tester.pumpAndSettle();

      expect(find.text('たま家に切り替えました'), findsOneWidget);
      expect((await states())['session.householdId'], 'h2');
      // おうち名の欄も、切り替えたおうちの名前になる
      expect(find.widgetWithText(TextField, 'たま家'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-MH-10 おうちが1つなら切り替えは出さない。作る・参加の入口はいつも出す', (tester) async {
      await (db.update(db.householdMembers)..where((m) => m.id.equals('m2')))
          .write(HouseholdMembersCompanion(deletedAt: Value(testTime)));
      await start(tester);

      expect(find.text('おうちを切り替える'), findsNothing);
      expect(find.text('新しいおうちを作る'), findsOneWidget);
      expect(find.text('招待されたおうちに参加'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-MH-11 新しいおうちを作ると、そのおうちが今のおうちになり、最初の猫の登録へ進む', (
      tester,
    ) async {
      await start(tester);
      await tester.ensureVisible(find.text('新しいおうちを作る'));
      await tester.tap(find.text('新しいおうちを作る'));
      await tester.pumpAndSettle();

      // 2つ目を作るときは、ログアウトと退会の入口・参加のボタンは出さない
      expect(find.text('ログアウト'), findsNothing);
      expect(find.text('招待されたおうちに参加'), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'とら家');
      await tester.tap(find.widgetWithText(FilledButton, '新しいおうちを作る'));
      await tester.pumpAndSettle();

      final current = (await states())['session.householdId'];
      expect(current, isNot(anyOf('h1', 'h2')));
      expect(
        (await (db.select(
          db.households,
        )..where((h) => h.id.equals(current!))).getSingle()).name,
        'とら家',
      );
      await close(tester);
    });
  });

  group('通知を押したとき', () {
    late StreamController<String?> taps;

    setUp(() => taps = StreamController<String?>.broadcast());
    tearDown(() => taps.close());

    Future<void> start(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tokenStoreProvider.overrideWithValue(tokens),
            apiClientProvider.overrideWithValue(fakeApiClient(server, tokens)),
          ],
          child: MeowScopeApp(notificationTaps: taps.stream),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('UT-MH-15 別のおうちの通知なら、そのおうちに切り替えて開く', (tester) async {
      await start(tester);
      taps.add('/?household=h2');
      await tester.pumpAndSettle();

      expect((await states())['session.householdId'], 'h2');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('UT-MH-16 異常系：もう入っていないおうちの通知は、切り替えず開かない', (tester) async {
      await start(tester);
      taps.add('/days/2026-11-07?household=h9');
      await tester.pumpAndSettle();

      expect((await states())['session.householdId'], 'h1');
      expect(find.byType(BackButton), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
