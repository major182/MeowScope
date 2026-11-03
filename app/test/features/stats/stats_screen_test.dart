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

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
        ],
        child: MaterialApp(home: StatsScreen(today: _today)),
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
}
