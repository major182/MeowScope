import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/presentation/home_screen.dart';
import 'package:meowscope/main.dart';

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
    await RecordRepository(db).addStandardTypes('h1');
  });

  tearDown(() => db.close());

  Future<void> show(WidgetTester tester, {Session? session = _session}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWithValue(session),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 画面を閉じて、DB の見張りを止める
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<List<RecordRow>> records() => db.select(db.records).get();

  testWidgets('UT-HM-01 おうちがなければ案内を出す', (tester) async {
    await show(tester, session: null);

    expect(find.text('おうちがまだありません'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-HM-02 標準の8項目をイラスト付きのボタンで出す', (tester) async {
    await show(tester);

    for (final name in ['ご飯', '水', '薬', 'おしっこ', 'うんち', '吐いた', '体重', 'ブラッシング']) {
      expect(find.widgetWithText(OutlinedButton, name), findsOneWidget);
    }
    expect(find.byType(Image), findsNWidgets(8));
    expect(find.text('まだ記録がありません'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-HM-03 猫がいなければ、記録せずに登録を促す', (tester) async {
    await show(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
    await tester.pumpAndSettle();

    expect(find.text('先に猫を登録してください'), findsOneWidget);
    expect(await records(), isEmpty);
    await close(tester);
  });

  testWidgets('UT-HM-04 猫が1匹なら、選ばずにすぐ保存して一覧に出す', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await show(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, '水'));
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsNothing);
    expect(find.text('ミケの水を記録しました'), findsOneWidget);
    expect(find.text('ミケ　水'), findsOneWidget);
    expect(await records(), hasLength(1));
    await close(tester);
  });

  testWidgets('UT-HM-05 猫が2匹なら、選んだ猫で保存する', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
    await show(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, '薬'));
    await tester.pumpAndSettle();
    expect(find.text('薬：どの子ですか？'), findsOneWidget);
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'タマ'));
    await tester.pumpAndSettle();

    expect(find.text('タマ　薬'), findsOneWidget);
    expect((await records()).single.catId, 'c2');
    await close(tester);
  });

  testWidgets('UT-HM-06 猫の選択を閉じたら保存しない', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
    await show(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsNothing);
    expect(await records(), isEmpty);
    await close(tester);
  });

  testWidgets('UT-HM-07 アプリを起動するとホームを表示する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MeowScopeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('おうちがまだありません'), findsOneWidget);
    await close(tester);
  });
}
