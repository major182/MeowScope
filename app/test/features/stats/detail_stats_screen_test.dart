import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/core/today.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/stats/presentation/detail_stats_screen.dart';
import 'package:meowscope/features/stats/presentation/stats_screen.dart';

import '../../helpers/test_db.dart';

const _author = Author(id: 'u1', name: 'はる');
const _session = Session(author: _author, householdId: 'h1');
final _today = DateTime(2026, 11, 25, 12);

/// くわしい統計（S-31。F-ST-04〜06、BR-42）
void main() {
  late AppDatabase db;

  setUp(() async {
    db = memoryDatabase();
    final repo = RecordRepository(db, clock: () => _today);
    await addHousehold(db, 'h1');
    await repo.addStandardTypes('h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(
      db,
      id: 'c2',
      householdId: 'h1',
      name: 'タマ',
      createdAt: testTime.add(const Duration(minutes: 1)),
    );
    final food = await (db.select(
      db.recordTypes,
    )..where((t) => t.kind.equals('food'))).getSingle();
    for (final cat in ['c1', 'c2']) {
      await repo.addRecord(catId: cat, recordTypeId: food.id, author: _author);
    }
  });
  tearDown(() => db.close());

  Future<void> show(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
          nowProvider.overrideWithValue(() => _today),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  LineChartData chart(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart)).data;

  testWidgets('UT-DS-04 S-30 の「くわしく見る」は Windows だけに出す（Android の統計は今のまま）', (
    tester,
  ) async {
    // 途中で失敗しても、後のテストに上書きを残さない（テストの終わりの確かめより前に戻す）
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await show(tester, StatsScreen(today: _today));
      expect(find.text('くわしく見る'), findsNothing);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await show(tester, StatsScreen(today: _today));
      expect(find.text('くわしく見る'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('UT-DS-05 はじめは月・先頭の猫・先頭の項目の1本。猫を足すと重なり、凡例に名前と目盛りを出す', (
    tester,
  ) async {
    await show(tester, const DetailStatsScreen());

    expect(chart(tester).lineBarsData, hasLength(1));
    expect(chart(tester).maxX, 29);
    expect(find.text('ミケ・ご飯（回・左）'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'タマ'));
    await tester.pumpAndSettle();
    expect(chart(tester).lineBarsData, hasLength(2));
    expect(find.text('タマ・ご飯（回・左）'), findsOneWidget);
    // 色の違う線にする
    final colors = chart(tester).lineBarsData.map((b) => b.color).toSet();
    expect(colors, hasLength(2));
  });

  testWidgets('UT-DS-06 体重を重ねると右の目盛り（kg）の破線になる。最後の1つは外せない', (tester) async {
    await show(tester, const DetailStatsScreen());

    await tester.tap(find.widgetWithText(FilterChip, '体重'));
    await tester.pumpAndSettle();
    expect(find.text('ミケ・体重（kg・右）'), findsOneWidget);
    final weight = chart(tester).lineBarsData[1];
    expect(weight.dashArray, isNotNull);

    // ご飯を外し、体重も外そうとしても1つは残る
    await tester.tap(find.widgetWithText(FilterChip, 'ご飯'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '体重'));
    await tester.pumpAndSettle();
    // 体重の記録がないので、グラフの代わりに案内を出す。凡例には残る
    expect(find.text('この期間の記録はありません'), findsOneWidget);
    expect(find.text('ミケ・体重（kg・右）'), findsOneWidget);
    expect(find.text('ミケ・ご飯（回・左）'), findsNothing);
  });

  testWidgets('UT-DS-07 期間：週・年に切り替えると日数が変わる。指定は両端を選ぶまで案内を出す', (tester) async {
    await show(tester, const DetailStatsScreen());

    await tester.tap(find.text('週'));
    await tester.pumpAndSettle();
    expect(chart(tester).maxX, 6);
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();
    expect(chart(tester).maxX, 364);

    await tester.tap(find.text('指定'));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('開始日と終了日を選んでください'), findsOneWidget);
  });

  testWidgets('UT-DS-08 境界値：線は8本まで。9本以上になるときは案内を出し、はじめの8本だけを描く', (
    tester,
  ) async {
    await show(tester, const DetailStatsScreen());
    // 猫2匹 × 項目4つ = 8本（ちょうど）、5つ目で10本
    await tester.tap(find.widgetWithText(FilterChip, 'タマ'));
    await tester.pumpAndSettle();
    // 押すたびに画面を進める（前の選択が反映されてから次を押す）
    for (final name in ['水', 'おしっこ', 'うんち']) {
      await tester.tap(find.widgetWithText(FilterChip, name));
      await tester.pumpAndSettle();
    }
    expect(chart(tester).lineBarsData, hasLength(8));
    expect(find.textContaining('はじめの8本だけ'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, '吐いた'));
    await tester.pumpAndSettle();
    expect(chart(tester).lineBarsData, hasLength(8));
    expect(find.textContaining('はじめの8本だけ'), findsOneWidget);
  });

  testWidgets('UT-DS-09 回数の項目だけを選んでも、期間に記録がなければ 0 の線ではなく案内を出す', (tester) async {
    await show(tester, const DetailStatsScreen());
    // 水の記録はない。ご飯を外して水だけにする
    await tester.tap(find.widgetWithText(FilterChip, '水'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'ご飯'));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('この期間の記録はありません'), findsOneWidget);
    expect(find.text('ミケ・水（回・左）'), findsOneWidget);
  });

  testWidgets('UT-DS-12 グラフの下に時間帯の傾向と日ごとの表を出す（同じ期間・猫・項目）', (tester) async {
    await show(tester, const DetailStatsScreen());
    await tester.tap(find.text('週'));
    await tester.pumpAndSettle();

    expect(find.text('時間帯の傾向'), findsOneWidget);
    expect(find.byType(HourTable), findsOneWidget);
    // 記録は今日の12時（12〜15時）に1件
    final hours = tester.widget<HourTable>(find.byType(HourTable));
    expect(hours.names, ['ご飯']);
    expect(hours.counts.single[4], 1);

    final table = tester.widget<DailyTable>(find.byType(DailyTable));
    expect(table.headers, ['ミケ・ご飯（回）']);
    expect(table.rows, hasLength(7));
    expect(table.rows.first.day, DateTime(2026, 11, 25));
    expect(table.rows.first.cells, ['1']);
    // 横にスクロールする表があるので、画面全体の縦のスクロールを動かす
    await tester.scrollUntilVisible(
      find.text('11/25（水）'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('11/25（水）'), findsOneWidget);
  });
}
