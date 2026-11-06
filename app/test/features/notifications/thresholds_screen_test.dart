import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/auth_repository.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/notifications/presentation/thresholds_screen.dart';
import 'package:meowscope/features/records/data/record_repository.dart';

import '../../helpers/test_db.dart';

const _session = Session(
  author: Author(id: 'u1', name: 'はる'),
  householdId: 'h1',
);

void main() {
  late AppDatabase db;

  setUp(() async {
    db = memoryDatabase();
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
    await (db.update(db.cats)..where((c) => c.id.equals('c2'))).write(
      const CatsCompanion(
        anomalyThresholds: Value('{"water":{"max":7},"weight":{"percent":9}}'),
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
          authUserProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'u1', name: 'はる')),
          ),
        ],
        child: const MaterialApp(home: ThresholdsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  /// [row] 番目の種類の下限（0）・上限（1）の欄
  Finder field(int row, int column) =>
      find.byType(TextField).at(row * 2 + column);

  Future<String?> stored(String id) async => (await (db.select(
    db.cats,
  )..where((c) => c.id.equals(id))).getSingle()).anomalyThresholds;

  testWidgets(
    'UT-TH-01 S-47：下限と上限を入れて保存すると、猫のしきい値として保存し同期待ちに入れる。体重が既定（5%）なら保存しない',
    (tester) async {
      await show(tester);
      expect(find.text('ミケ'), findsOneWidget);

      await tester.enterText(field(0, 0), '2');
      await tester.enterText(field(0, 1), '5');
      await tester.tap(find.widgetWithText(FilledButton, '保存する'));
      await tester.pumpAndSettle();

      expect(find.text('しきい値を保存しました'), findsOneWidget);
      expect(await stored('c1'), '{"food":{"min":2,"max":5}}');
      final pending = await db.select(db.pendingChanges).getSingle();
      expect((pending.targetTable, pending.rowId), ('cats', 'c1'));
      await close(tester);
    },
  );

  testWidgets(
    'UT-TH-02 S-47 の入力チェック（境界値）：回数は 0〜99、下限は上限以下、体重は 1〜50。誤りがあれば保存しない',
    (tester) async {
      await show(tester);
      await tester.enterText(field(0, 0), '100');
      await tester.enterText(field(1, 0), '3');
      await tester.enterText(field(1, 1), '2');
      await tester.enterText(find.byType(TextField).last, '51');
      await tester.tap(find.widgetWithText(FilledButton, '保存する'));
      await tester.pumpAndSettle();

      expect(find.text(countRangeMessage), findsOneWidget);
      expect(find.text(minMaxMessage), findsOneWidget);
      expect(find.text(percentRangeMessage), findsOneWidget);
      expect(await stored('c1'), isNull);

      await tester.enterText(field(0, 0), '99');
      await tester.enterText(field(1, 0), '2');
      await tester.enterText(find.byType(TextField).last, '50');
      await tester.tap(find.widgetWithText(FilledButton, '保存する'));
      await tester.pumpAndSettle();
      expect(
        await stored('c1'),
        '{"food":{"min":99},"water":{"min":2,"max":2},"weight":{"percent":50}}',
      );
      await close(tester);
    },
  );

  testWidgets('UT-TH-03 S-47：猫を切り替えると、その猫の保存したしきい値を出す', (tester) async {
    await show(tester);
    await tester.tap(find.text('ミケ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('タマ').last);
    await tester.pumpAndSettle();

    final water = tester.widget<TextField>(field(1, 1));
    expect(water.controller!.text, '7');
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      '9',
    );
    await close(tester);
  });
}
