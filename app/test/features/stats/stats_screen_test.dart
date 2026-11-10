import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/stats/presentation/stats_screen.dart';

import '../../helpers/test_db.dart';

const _author = Author(id: 'u1', name: 'はる');
const _session = Session(author: _author, householdId: 'h1');
final _today = DateTime(2026, 11, 2);

void main() {
  late AppDatabase db;
  late DateTime now;
  late RecordRepository repo;

  setUp(() async {
    db = memoryDatabase();
    now = _today;
    repo = RecordRepository(db, clock: () => now);
    await addHousehold(db, 'h1');
    await repo.addStandardTypes('h1');
  });

  tearDown(() => db.close());

  /// 記録を1件作る。ウィジェットのテストの中では DB の見張りが進まないので、直接読む
  Future<void> record(
    String catId,
    String kind,
    DateTime at, {
    double? kg,
  }) async {
    final type = await (db.select(
      db.recordTypes,
    )..where((t) => t.kind.equals(kind))).getSingle();
    now = at;
    final id = await repo.addRecord(
      catId: catId,
      recordTypeId: type.id,
      author: _author,
    );
    if (kg != null) {
      await repo.updateRecord(
        id: id,
        recordedAt: at,
        level: null,
        valueNumber: kg,
        memo: null,
        author: _author,
      );
    }
  }

  Future<void> show(
    WidgetTester tester, {
    String? catId,
    String? kind,
    DateTime? day,
    double height = 1200,
  }) async {
    tester.view.physicalSize = Size(500, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
        ],
        child: MaterialApp(
          home: StatsScreen(today: _today, catId: catId, kind: kind, day: day),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  List<double> bars(WidgetTester tester) => [
    for (final g
        in tester.widget<BarChart>(find.byType(BarChart)).data.barGroups)
      g.barRods.single.toY,
  ];

  testWidgets('UT-SS-06 猫がいなければ、その旨を出す', (tester) async {
    await show(tester);

    expect(find.text('猫が登録されていません'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-SS-07 最初の猫の、週の体重とご飯の回数を出す', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await record('c1', 'weight', DateTime(2026, 10, 30, 8), kg: 4.1);
    await record('c1', 'weight', DateTime(2026, 11, 2, 8), kg: 4.2);
    await record('c1', 'food', DateTime(2026, 11, 2, 8));
    await record('c1', 'food', DateTime(2026, 11, 2, 18));
    await show(tester);

    expect(find.text('ミケ'), findsOneWidget);
    final line = tester.widget<LineChart>(find.byType(LineChart));
    expect(line.data.lineBarsData.single.spots.map((s) => s.y), [4.1, 4.2]);
    expect(bars(tester), [0, 0, 0, 0, 0, 0, 2]);
    await close(tester);
  });

  testWidgets('UT-SS-08 体重の記録がなければ、その旨を出す。回数は0で出す', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await show(tester);

    expect(find.text('この期間の体重の記録はありません'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(bars(tester), List.filled(7, 0.0));
    await close(tester);
  });

  testWidgets('UT-SS-09 月に切り替えると30日分になり、期間の前の記録も入る', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await record('c1', 'food', DateTime(2026, 10, 10, 8));
    await show(tester);
    expect(bars(tester).reduce((a, b) => a + b), 0);

    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();

    expect(bars(tester), hasLength(30));
    expect(bars(tester).reduce((a, b) => a + b), 1);
    await close(tester);
  });

  testWidgets('UT-SS-10 回数の項目を切り替える。体重は選べない', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await record('c1', 'water', DateTime(2026, 11, 1, 8));
    await show(tester);

    await tester.tap(find.text('ご飯'));
    await tester.pumpAndSettle();
    expect(find.text('体重').hitTestable(), findsNothing);
    await tester.tap(find.text('水').last);
    await tester.pumpAndSettle();

    expect(bars(tester), [0, 0, 0, 0, 0, 1, 0]);
    await close(tester);
  });

  testWidgets('UT-SS-11 猫を切り替えると、その猫の記録にする', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(
      db,
      id: 'c2',
      householdId: 'h1',
      name: 'タマ',
      createdAt: DateTime.utc(2026, 11, 3),
    );
    await record('c2', 'food', DateTime(2026, 11, 2, 8));
    await show(tester);
    expect(bars(tester).last, 0);

    await tester.tap(find.text('ミケ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('タマ').last);
    await tester.pumpAndSettle();

    expect(bars(tester).last, 1);
    await close(tester);
  });

  test('UT-SS-12 日付の目盛りを出す日：週は毎日、月は最後の日から5日おき。範囲の外と整数でない値は出さない', () {
    final week = [for (var i = 0; i < 7; i++) DateTime(2026, 10, 27 + i)];
    expect(
      [for (var i = 0; i < 7; i++) isLabelDay(week, i.toDouble())],
      [for (var i = 0; i < 7; i++) true],
    );
    expect(isLabelDay(week, -1), isFalse);
    expect(isLabelDay(week, 7), isFalse);
    expect(isLabelDay(week, 0.5), isFalse);

    final month = [for (var i = 0; i < 30; i++) DateTime(2026, 10, 4 + i)];
    final labelled = [
      for (var i = 0; i < 30; i++)
        if (isLabelDay(month, i.toDouble())) i,
    ];
    expect(labelled, [4, 9, 14, 19, 24, 29]);
  });

  testWidgets('UT-SS-13 縦の線：棒グラフは引かず、折れ線グラフは日付の目盛りの日にだけ引く', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await record('c1', 'weight', DateTime(2026, 11, 2, 8), kg: 4.2);
    await show(tester);

    final bar = tester.widget<BarChart>(find.byType(BarChart));
    expect(bar.data.gridData.drawVerticalLine, isFalse);
    final line = tester.widget<LineChart>(find.byType(LineChart));
    final grid = line.data.gridData;
    expect(grid.verticalInterval, 1);
    expect(grid.checkToShowVerticalLine(6), isTrue);
    expect(grid.checkToShowVerticalLine(6.5), isFalse);
    await close(tester);
  });

  testWidgets('UT-SS-14 いつもとの差の通知から開くと、その猫と項目を選んでおく。体重・知らない猫は初めの選び方にする', (
    tester,
  ) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(
      db,
      id: 'c2',
      householdId: 'h1',
      name: 'タマ',
      createdAt: testTime.add(const Duration(days: 1)),
    );
    await record('c2', 'vomit', DateTime(2026, 11, 2, 8));
    await show(tester, catId: 'c2', kind: 'vomit');
    expect(find.text('タマ'), findsOneWidget);
    expect(find.text('吐いた'), findsOneWidget);
    expect(bars(tester), [0, 0, 0, 0, 0, 0, 1]);
    await close(tester);

    await show(tester, catId: 'none', kind: 'weight');
    expect(find.text('ミケ'), findsOneWidget);
    expect(find.text('ご飯'), findsOneWidget);
    await close(tester);
  });

  /// ミケ（c1）に、10/25〜10/31 の7日、毎日ご飯を3回
  Future<void> usualWeek() async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    for (var d = 25; d <= 31; d++) {
      for (var h = 8; h < 11; h++) {
        await record('c1', 'food', DateTime(2026, 10, d, h));
      }
    }
  }

  testWidgets('UT-SS-15 体調のようす：初めはきのう。外れ値を上に、その下に範囲内を出す', (tester) async {
    await usualWeek();
    await record('c1', 'food', DateTime(2026, 11, 1, 8));
    await show(tester, height: 2400);
    expect(find.text('体調のようす'), findsOneWidget);
    expect(find.text('11/1(日)'), findsOneWidget);
    expect(find.text('外れ値 1個'), findsOneWidget);
    expect(find.text('ご飯　1回'), findsOneWidget);
    expect(find.text('少なめ'), findsOneWidget);
    expect(find.text('ふだん 3回'), findsOneWidget);
    expect(find.text('水　0回'), findsOneWidget);
    expect(find.text('ふだん 0回'), findsWidgets);
    expect(find.text('体重　記録なし'), findsOneWidget);
    // 外れ値の見出しとご飯が、範囲内の見出しより上
    final top = tester.getTopLeft(find.text('範囲内')).dy;
    expect(tester.getTopLeft(find.text('外れ値 1個')).dy, lessThan(top));
    expect(tester.getTopLeft(find.text('ご飯　1回')).dy, lessThan(top));
    expect(tester.getTopLeft(find.text('水　0回')).dy, greaterThan(top));
    await close(tester);
  });

  testWidgets(
    'UT-SS-16 体調のようす：日付を切り替える。今日より先には進めず、今日は上限だけを出す（説明の文は出さない）。記録のない日はその旨を出す',
    (tester) async {
      await usualWeek();
      await show(tester, height: 2400);
      expect(find.text('この日は記録がないため、少なすぎは見ません'), findsOneWidget);
      expect(find.text('外れ値はありません'), findsOneWidget);

      await tester.tap(find.byTooltip('次の日'));
      await tester.pumpAndSettle();
      expect(find.text('11/2(月)'), findsOneWidget);
      expect(find.text('きょうは途中なので、多すぎだけを見ます'), findsNothing);
      expect(find.text('ふだん 3回以下'), findsOneWidget);
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(next.onPressed, isNull);

      await tester.tap(find.byTooltip('前の日'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('前の日'));
      await tester.pumpAndSettle();
      expect(find.text('10/31(土)'), findsOneWidget);
      await close(tester);
    },
  );

  testWidgets('UT-SS-17 体調のようす：記録が7日分に満たなければ、あと何日かを出す。通知から開くと、その日を出す', (
    tester,
  ) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    for (var d = 26; d <= 31; d++) {
      await record('c1', 'food', DateTime(2026, 10, d, 8));
    }
    await show(tester, height: 2400);
    expect(find.text('まだ判定できません（記録が7日分たまると判定します。あと1日）'), findsOneWidget);
    await close(tester);

    await show(tester, height: 2400, catId: 'c1', day: DateTime(2026, 10, 20));
    expect(find.text('10/20(火)'), findsOneWidget);
    await close(tester);
  });
}
