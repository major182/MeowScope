import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/app/router.dart' show createRouter;
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/core/today.dart';
import 'package:meowscope/features/calendar/presentation/calendar_screen.dart';
import 'package:meowscope/features/calendar/presentation/day_record_add.dart';
import 'package:meowscope/features/calendar/presentation/day_records.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/domain/record_detail.dart';

import '../../helpers/balanced_text_finder.dart';
import '../../helpers/test_db.dart';

const _author = Author(id: 'u1', name: 'はる');
const _session = Session(author: _author, householdId: 'h1');

/// 今：2026-11-19 10:30
final _now = DateTime(2026, 11, 19, 10, 30);

void main() {
  group('日付から記録を始められるか（BR-35）', () {
    test('UT-DA-01 境界値：昨日・今日（0時・23時59分の今）は始められ、明日は始められない', () {
      expect(canRecordOn(DateTime(2026, 11, 18), _now), isTrue);
      expect(canRecordOn(DateTime(2026, 11, 19), _now), isTrue);
      expect(
        canRecordOn(DateTime(2026, 11, 19), DateTime(2026, 11, 19)),
        isTrue,
      );
      expect(
        canRecordOn(DateTime(2026, 11, 19), DateTime(2026, 11, 19, 23, 59)),
        isTrue,
      );
      expect(canRecordOn(DateTime(2026, 11, 20), _now), isFalse);
      expect(
        canRecordOn(DateTime(2026, 11, 20), DateTime(2026, 11, 19, 23, 59)),
        isFalse,
      );
    });

    test('UT-DA-02 日時の既定：過去の日は選んだ日＋今の時刻、今日は今（秒を含めて未来にしない）', () {
      expect(
        defaultRecordedAt(DateTime(2026, 11, 2), _now),
        DateTime(2026, 11, 2, 10, 30),
      );
      final now = DateTime(2026, 11, 19, 10, 30, 15);
      // 今日：分にそろえた時刻は今より前なので、そのまま
      expect(
        defaultRecordedAt(DateTime(2026, 11, 19), now),
        DateTime(2026, 11, 19, 10, 30),
      );
      expect(
        validateRecordedAt(defaultRecordedAt(DateTime(2026, 11, 19), now), now),
        isNull,
      );
      // 年をまたぐ過去の日
      expect(
        defaultRecordedAt(DateTime(2025, 12, 31), _now),
        DateTime(2025, 12, 31, 10, 30),
      );
    });
  });

  late AppDatabase db;
  late RecordRepository repo;

  setUp(() async {
    db = memoryDatabase();
    repo = RecordRepository(db, clock: () => _now);
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await repo.addStandardTypes('h1');
  });

  tearDown(() => db.close());

  Future<RecordTypeRow> type(String kind) => (db.select(
    db.recordTypes,
  )..where((t) => t.kind.equals(kind))).getSingle();

  Future<List<RecordRow>> live() =>
      (db.select(db.records)..where((r) => r.deletedAt.isNull())).get();

  test('UT-DA-03 日時を渡すと、その日時で記録し、同期待ちにも同じ日時を入れる', () async {
    final food = await type('food');
    final at = DateTime(2026, 11, 2, 10, 30);
    final id = await repo.addRecord(
      catId: 'c1',
      recordTypeId: food.id,
      author: _author,
      recordedAt: at,
    );

    final row = await (db.select(
      db.records,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(row.recordedAt.toLocal(), at);
    final pending = await db.select(db.pendingChanges).getSingle();
    expect(
      jsonDecode(pending.payload)['recordedAt'],
      at.toUtc().toIso8601String(),
    );
  });

  /// 画面を出す。③の詳細入力は、保存したか戻ったかを返すだけの目印に置き換える
  Future<GoRouter> show(
    WidgetTester tester,
    String location, {
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (context, state) =>
              CalendarScreen(today: DateTime(2026, 11, 19)),
        ),
        GoRoute(
          path: '/days/:date',
          builder: (context, state) =>
              DayListScreen(day: DateTime.parse(state.pathParameters['date']!)),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => DayRecordAddScreen(
                day: DateTime.parse(state.pathParameters['date']!),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/records/:id/edit',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('詳細入力'),
                TextButton(
                  onPressed: () => context.pop(true),
                  child: const Text('保存した'),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('戻った'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
          nowProvider.overrideWithValue(() => _now),
          recordRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  group('カレンダーの長押し（S-20）', () {
    testWidgets('UT-DA-04 過去の日と今日を長押しすると、その日の記録（S-24）を始める', (tester) async {
      final router = await show(tester, '/calendar');

      await tester.longPress(find.byKey(const ValueKey('day-11-2')));
      await tester.pumpAndSettle();
      expect(find.text('11月2日の記録'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('day-11-19')));
      await tester.pumpAndSettle();
      expect(find.text('11月19日の記録'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-DA-05 未来の日（明日）は長押ししても何もしない', (tester) async {
      await show(tester, '/calendar');

      await tester.longPress(find.byKey(const ValueKey('day-11-20')));
      await tester.pumpAndSettle();
      expect(find.text('11月20日の記録'), findsNothing);
      expect(find.text('カレンダー'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-DA-06 広い幅では、右の日別一覧にも「記録を追加」を出す', (tester) async {
      await show(tester, '/calendar', width: 1280);

      await tester.tap(find.text('記録を追加'));
      await tester.pumpAndSettle();
      expect(find.text('11月19日の記録'), findsOneWidget);
      await close(tester);
    });
  });

  group('日別一覧の「記録を追加」（S-21）', () {
    testWidgets('UT-DA-07 過去の日と今日には出し、押すとその日の記録を始める', (tester) async {
      await show(tester, '/days/2026-11-19');
      expect(find.byTooltip('記録を追加'), findsOneWidget);

      // 前の日へ移っても出る
      await tester.tap(find.byTooltip('前の日'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('記録を追加'));
      await tester.pumpAndSettle();
      expect(find.text('11月18日の記録'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-DA-08 未来の日（明日）には出さない', (tester) async {
      await show(tester, '/days/2026-11-19');

      await tester.tap(find.byTooltip('次の日'));
      await tester.pumpAndSettle();
      expect(find.text('11月 20日'), findsOneWidget);
      expect(find.byTooltip('記録を追加'), findsNothing);
      await close(tester);
    });
  });

  testWidgets('UT-DA-15 境界値：狭い幅（320px）でも、見出しの日付と「記録を追加」がはみ出さない', (
    tester,
  ) async {
    await show(tester, '/days/2026-11-19', width: 320);

    expect(tester.takeException(), isNull);
    expect(find.text('11月 19日'), findsOneWidget);
    expect(find.byTooltip('記録を追加'), findsOneWidget);
    await close(tester);
  });

  group('日付からの記録（S-24）', () {
    testWidgets('UT-DA-09 項目を押すと、選んだ日＋今の時刻で記録して③へ進み、保存したら日別一覧へ戻る', (
      tester,
    ) async {
      await show(tester, '/days/2026-11-02');
      await tester.tap(find.byTooltip('記録を追加'));
      await tester.pumpAndSettle();

      // 猫が1匹なので選択を省く
      await tester.tap(find.text('ご飯'));
      await tester.pumpAndSettle();
      expect(find.text('詳細入力'), findsOneWidget);
      final rows = await live();
      expect(rows, hasLength(1));
      expect(rows.single.recordedAt.toLocal(), DateTime(2026, 11, 2, 10, 30));

      await tester.tap(find.text('保存した'));
      await tester.pumpAndSettle();
      expect(find.text('11月 2日'), findsOneWidget);
      expect(find.text('11月2日の記録'), findsNothing);
      expect(await live(), hasLength(1));
      await close(tester);
    });

    testWidgets('UT-DA-10 ③で保存せずに戻ると、作った記録を消して①に戻る', (tester) async {
      await show(tester, '/days/2026-11-02/new');

      await tester.tap(find.text('ご飯'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('戻った'));
      await tester.pumpAndSettle();

      expect(find.text('11月2日の記録'), findsOneWidget);
      expect(await live(), isEmpty);
      await close(tester);
    });

    testWidgets('UT-DA-11 猫が2匹なら選んだ猫で記録し、選ばずに閉じたら記録しない', (tester) async {
      await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
      await show(tester, '/days/2026-11-02/new');

      await tester.tap(find.text('水'));
      await tester.pumpAndSettle();
      expect(findBalancedText('水：どの子ですか？'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(await live(), isEmpty);

      await tester.tap(find.text('水'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('タマ'));
      await tester.pumpAndSettle();
      expect((await live()).single.catId, 'c2');
      await close(tester);
    });

    testWidgets('UT-DA-12 猫がいなければ記録せずに案内を出す', (tester) async {
      await db.delete(db.cats).go();
      await show(tester, '/days/2026-11-02/new');

      await tester.tap(find.text('ご飯'));
      await tester.pumpAndSettle();
      expect(find.text('先に猫を登録してください'), findsOneWidget);
      expect(await live(), isEmpty);
      await close(tester);
    });

    testWidgets('UT-DA-13 未来の日の道筋を直接開いても、記録を始めない', (tester) async {
      await show(tester, '/days/2026-11-20/new');

      expect(find.text('未来の日には記録できません'), findsOneWidget);
      expect(find.text('ご飯'), findsNothing);
      await close(tester);
    });
  });

  test('UT-DA-14 アプリの道筋に、日付からの記録（/days/:date/new）がある', () {
    final router = createRouter();
    addTearDown(router.dispose);
    expect(
      router.configuration
          .findMatch(Uri.parse('/days/2026-11-02/new'))
          .isNotEmpty,
      isTrue,
    );
  });
}
