import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/domain/custom_type.dart';
import 'package:meowscope/features/records/presentation/home_screen.dart';
import 'package:meowscope/features/records/presentation/record_types_screen.dart';

import '../../helpers/test_db.dart';

const _author = Author(id: 'u1', name: 'はる');
const _session = Session(author: _author, householdId: 'h1');

void main() {
  late AppDatabase db;
  late RecordRepository repo;

  setUp(() async {
    db = memoryDatabase();
    repo = RecordRepository(db);
    await addHousehold(db, 'h1');
    await repo.addStandardTypes('h1');
  });

  tearDown(() => db.close());

  Future<String> addCustom(String name) => repo.addCustomType(
    householdId: 'h1',
    userId: 'u1',
    name: name,
    icon: CustomIcon.treat.value,
  );

  Future<List<RecordTypeRow>> customTypes() =>
      (db.select(db.recordTypes)..where((t) => t.kind.equals('custom'))).get();

  Future<void> show(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'record-types',
              builder: (context, state) => const RecordTypesScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const RecordTypeFormScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      RecordTypeFormScreen(typeId: state.pathParameters['id']),
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

  testWidgets('UT-TY-09 標準の項目には（標準）を付け、独自の項目にだけ「編集」を出す', (tester) async {
    await addCustom('通院');
    await show(tester, '/record-types');

    expect(find.text('ご飯（標準）'), findsOneWidget);
    expect(find.text('ブラッシング（標準）'), findsOneWidget);
    expect(find.text('通院'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '編集'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-TY-10 名前とアイコンを選んで追加すると、一覧とホームに出る', (tester) async {
    await show(tester, '/record-types');

    await tester.tap(find.widgetWithText(TextButton, '追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '名前'), '爪切り');
    await tester.tap(find.widgetWithText(ChoiceChip, '爪切り'));
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    final saved = (await customTypes()).single;
    expect(saved.name, '爪切り');
    expect(saved.icon, 'custom_nail');
    expect(find.text('記録項目'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '爪切り'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/icons/custom_nail.png')),
      findsWidgets,
    );
    await close(tester);
  });

  testWidgets('UT-TY-11 異常系：空や同じ名前では追加しない', (tester) async {
    await show(tester, '/record-types/new');

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('名前を入力してください'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), '水');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('同じ名前の項目があります'), findsOneWidget);
    expect(await customTypes(), isEmpty);
    await close(tester);
  });

  testWidgets('UT-TY-12 編集では登録した内容を入れて開き、同じ名前のままでも保存できる', (tester) async {
    final id = await addCustom('通院');
    await show(tester, '/record-types/$id');

    expect(find.widgetWithText(TextFormField, '通院'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'おやつ'))
          .selected,
      isTrue,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'その他'));
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    final saved = (await customTypes()).single;
    expect(saved.name, '通院');
    expect(saved.icon, 'custom_other');
    await close(tester);
  });

  testWidgets('UT-TY-13 異常系：標準の項目や存在しない項目は、見つからないと表示する', (tester) async {
    final food = await (db.select(
      db.recordTypes,
    )..where((t) => t.kind.equals('food'))).getSingle();
    await show(tester, '/record-types/${food.id}');
    expect(find.text('この項目は見つかりません'), findsOneWidget);
    await close(tester);

    await show(tester, '/record-types/none');
    expect(find.text('この項目は見つかりません'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-HD-06 非表示にするとホームのボタンから消え、表示に戻すと出る。削除のボタンはない', (tester) async {
    await addCustom('通院');
    await show(tester, '/record-types');
    expect(find.text('削除'), findsNothing);
    // 標準の項目には非表示のボタンを出さない
    expect(find.widgetWithText(TextButton, '非表示にする'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '非表示にする'));
    await tester.pumpAndSettle();
    expect((await customTypes()).single.hidden, isTrue);
    expect(find.text('非表示（過去の記録は残ります）'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '通院'), findsNothing);
    await close(tester);
    await show(tester, '/record-types');
    await tester.tap(find.widgetWithText(TextButton, '表示に戻す'));
    await tester.pumpAndSettle();
    expect((await customTypes()).single.hidden, isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '通院'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-HD-07 異常系：非表示の項目と同じ名前では追加できない', (tester) async {
    final id = await addCustom('通院');
    await repo.setTypeHidden(id: id, userId: 'u1', hidden: true);
    await show(tester, '/record-types/new');

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), '通院');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('同じ名前の項目があります'), findsOneWidget);
    expect(await customTypes(), hasLength(1));
    await close(tester);
  });
}
