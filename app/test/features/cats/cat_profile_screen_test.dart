import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/cats/presentation/cat_form_screen.dart';
import 'package:meowscope/features/cats/presentation/cat_list_screen.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';

import '../../helpers/balanced_text_finder.dart';
import '../../helpers/test_db.dart';

const _author = Author(id: 'u1', name: 'はる');
const _session = Session(author: _author, householdId: 'h1');
final _today = DateTime(2026, 11, 3);

void main() {
  late AppDatabase db;

  setUp(() async {
    db = memoryDatabase();
    await addHousehold(db, 'h1');
  });

  tearDown(() => db.close());

  Future<CatRow?> cat(String id) =>
      (db.select(db.cats)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<void> show(WidgetTester tester, String location) async {
    // 削除のボタンが画面に収まる高さにする
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('戻り先'),
          routes: [
            GoRoute(
              path: 'cats',
              builder: (context, state) => CatListScreen(today: _today),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) =>
                      Scaffold(appBar: AppBar(title: const Text('登録画面'))),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => CatProfileScreen(
                    catId: state.pathParameters['id']!,
                    today: _today,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(_session)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  group('猫の一覧（S-41）', () {
    testWidgets('UT-CP-11 猫がいなければ、その旨を出す', (tester) async {
      await show(tester, '/cats');

      expect(find.text('猫が登録されていません'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-CP-12 年齢とお別れを出し、削除済みは出さない', (tester) async {
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await db.customStatement(
        "UPDATE cats SET birth_date = ${DateTime.utc(2023, 4, 5).millisecondsSinceEpoch ~/ 1000} WHERE id = 'c1'",
      );
      await addCat(
        db,
        id: 'c2',
        householdId: 'h1',
        name: 'ソラ',
        status: 'farewell',
      );
      await addCat(
        db,
        id: 'c3',
        householdId: 'h1',
        name: 'クロ',
        deletedAt: _today,
      );
      await show(tester, '/cats');

      expect(find.widgetWithText(ListTile, 'ミケ'), findsOneWidget);
      expect(find.text('3歳'), findsOneWidget);
      expect(find.text('お別れ'), findsOneWidget);
      expect(find.text('クロ'), findsNothing);
      await close(tester);
    });

    testWidgets('UT-CP-13 「追加」で登録へ、猫を押すとプロフィールへ進む', (tester) async {
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await show(tester, '/cats');

      await tester.tap(find.widgetWithText(TextButton, '追加'));
      await tester.pumpAndSettle();
      expect(find.text('登録画面'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('ミケ'));
      await tester.pumpAndSettle();
      expect(find.text('ミケのプロフィール'), findsOneWidget);
      await close(tester);
    });
  });

  group('猫のプロフィール（S-41）', () {
    testWidgets('UT-CP-14 登録した内容を入れて開き、編集して保存すると戻る', (tester) async {
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await show(tester, '/cats/c1');
      expect(find.widgetWithText(TextFormField, 'ミケ'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, '名前'), 'ミケコ');
      await tester.tap(find.text('女の子'));
      await tester.enterText(find.widgetWithText(TextFormField, '持病'), '腎臓');
      await tester.tap(find.widgetWithText(FilledButton, '保存する'));
      await tester.pumpAndSettle();

      final saved = (await cat('c1'))!;
      expect(saved.name, 'ミケコ');
      expect(saved.sex, 'female');
      expect(saved.conditions, '腎臓');
      expect(find.text('ミケコ'), findsOneWidget);
      expect(find.text('ミケコを保存しました'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-CP-15 異常系：名前を空にすると保存しない', (tester) async {
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await show(tester, '/cats/c1');

      await tester.enterText(find.widgetWithText(TextFormField, 'ミケ'), ' ');
      await tester.tap(find.widgetWithText(FilledButton, '保存する'));
      await tester.pumpAndSettle();

      expect(find.text('名前を入力してください'), findsOneWidget);
      expect((await cat('c1'))!.name, 'ミケ');
      await close(tester);
    });

    testWidgets('UT-CP-16 お別れにする・取り消す', (tester) async {
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await show(tester, '/cats/c1');

      await tester.tap(find.widgetWithText(OutlinedButton, 'お別れにする'));
      await tester.pumpAndSettle();
      expect((await cat('c1'))!.status, 'farewell');
      expect(find.text('お別れの猫は記録の対象から外れます。記録は残ります'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'お別れを取り消す'));
      await tester.pumpAndSettle();
      expect((await cat('c1'))!.status, 'active');
      await close(tester);
    });

    testWidgets('UT-CP-17 削除の確認でキャンセルすると残す。ボタンは左に削除（BR-29）', (tester) async {
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await show(tester, '/cats/c1');

      await tester.tap(find.widgetWithText(TextButton, '削除する'));
      await tester.pumpAndSettle();
      expect(findBalancedText('ミケを削除しますか？'), findsOneWidget);
      final dialog = find.byType(AlertDialog);
      final delete = find.descendant(of: dialog, matching: find.text('削除'));
      final cancel = find.descendant(of: dialog, matching: find.text('キャンセル'));
      expect(
        tester.getCenter(delete).dx,
        lessThan(tester.getCenter(cancel).dx),
      );

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect((await cat('c1'))!.deletedAt, isNull);
      await close(tester);
    });

    testWidgets('UT-CP-18 削除すると消して、一覧へ戻る', (tester) async {
      await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
      await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
      await show(tester, '/cats/c1');

      await tester.tap(find.widgetWithText(TextButton, '削除する'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('削除'),
        ),
      );
      await tester.pumpAndSettle();

      expect((await cat('c1'))!.deletedAt, isNotNull);
      expect(find.text('タマ'), findsOneWidget);
      expect(find.text('ミケ'), findsNothing);
      await close(tester);
    });

    testWidgets('UT-CP-19 猫がいなければ、見つからないと表示する', (tester) async {
      await show(tester, '/cats/none');

      expect(find.text('この猫は見つかりません'), findsOneWidget);
      await close(tester);
    });
  });
}
