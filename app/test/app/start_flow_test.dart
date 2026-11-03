import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/main.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MeowScopeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> createHousehold(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'あなたの名前'), 'はる');
    await tester.enterText(find.widgetWithText(TextFormField, 'おうちの名前'), 'みけ家');
    await tester.tap(find.widgetWithText(FilledButton, '新しいおうちを作る'));
    await tester.pumpAndSettle();
  }

  testWidgets('UT-ST-01 おうちがなければ、おうちの作成を出す', (tester) async {
    await start(tester);

    expect(find.text('おうちを準備します'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-ST-02 名前とおうちの名前が空欄なら作らない', (tester) async {
    await start(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'あなたの名前'), ' ');
    await tester.tap(find.widgetWithText(FilledButton, '新しいおうちを作る'));
    await tester.pumpAndSettle();

    expect(find.text('あなたの名前を入力してください'), findsOneWidget);
    expect(find.text('おうちの名前を入力してください'), findsOneWidget);
    expect(await db.select(db.households).get(), isEmpty);
    await close(tester);
  });

  testWidgets('UT-ST-03 おうちを作り、猫を登録して、記録するまでの流れ', (tester) async {
    await start(tester);

    await createHousehold(tester);
    expect(find.text('猫を登録しましょう'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), 'ミケ');
    await tester.tap(find.widgetWithText(FilledButton, '登録する'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'ホーム'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
    await tester.pumpAndSettle();
    expect(find.text('ミケ　ご飯'), findsOneWidget);
    final record = await db.select(db.records).getSingle();
    expect(record.authorName, 'はる');
    await close(tester);
  });

  testWidgets('UT-ST-04 次に開いたときは、作ったおうちのホームを出す', (tester) async {
    await start(tester);
    await createHousehold(tester);
    await close(tester);

    await start(tester);

    expect(find.widgetWithText(AppBar, 'ホーム'), findsOneWidget);
    expect(find.text('猫が登録されていません'), findsOneWidget);
    await close(tester);
  });
}
