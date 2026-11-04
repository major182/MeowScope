import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/presentation/home_screen.dart';

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

  /// ホームだけを出す。猫の登録画面は目印の文字に置き換える
  Future<void> show(WidgetTester tester, {Session? session = _session}) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/cats/new',
          builder: (context, state) => const Text('猫の登録画面'),
        ),
        GoRoute(
          path: '/records/:id',
          builder: (context, state) => Text('詳細：${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/records/:id/edit',
          builder: (context, state) =>
              Text('詳細入力：${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => Stream.value(session)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // セッションがないときは読み込み中の表示が回り続けるので、落ち着くまでは待たない
    if (session == null) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  /// 画面を閉じて、DB の見張りを止める
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<List<RecordRow>> records() => db.select(db.records).get();

  testWidgets('UT-HM-01 セッションがなければ、記録のボタンを出さずに待つ', (tester) async {
    await show(tester, session: null);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
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
    expect(find.text('猫が登録されていません'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
    await tester.pumpAndSettle();

    expect(find.text('先に猫を登録してください'), findsOneWidget);
    expect(await records(), isEmpty);
    await close(tester);
  });

  testWidgets('UT-HM-04 猫が1匹なら、選ばずにすぐ保存して一覧に出す', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await show(tester);
    expect(find.text('猫が登録されていません'), findsNothing);

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

  testWidgets('UT-HM-07 「登録する」で猫の登録画面へ進む', (tester) async {
    await show(tester);

    await tester.tap(find.widgetWithText(FilledButton, '登録する'));
    await tester.pumpAndSettle();

    expect(find.text('猫の登録画面'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-HM-08 猫がいても「猫を追加」で登録画面へ進める', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await show(tester);

    await tester.tap(find.text('猫を追加'));
    await tester.pumpAndSettle();

    expect(find.text('猫の登録画面'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-HM-09 保存の後の「詳細を追加」で、その記録の詳細入力へ進む', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await show(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SnackBarAction, '詳細を追加'));
    await tester.pumpAndSettle();

    final id = (await records()).single.id;
    expect(find.text('詳細入力：$id'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-HM-11 保存の後の通知は4秒で消える（境界値：4秒の直前は出ている）', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await show(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
    await tester.pumpAndSettle();
    expect(find.text('ミケのご飯を記録しました'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.text('ミケのご飯を記録しました'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('ミケのご飯を記録しました'), findsNothing);
    await close(tester);
  });

  group('UT-HM-12 記録のボタンの並べ方', () {
    Future<List<Rect>> buttonsAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await show(tester);
      return [
        for (final e in find.byType(OutlinedButton).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
    }

    testWidgets('広い画面（1280px）：ボタンは 160px 以下で、8つが1列に並ぶ', (tester) async {
      final rects = await buttonsAt(tester, 1280);
      expect(rects, hasLength(8));
      expect(rects.every((r) => r.width <= typeButtonMaxWidth), isTrue);
      expect(rects.map((r) => r.top).toSet(), hasLength(1));
      await close(tester);
    });

    testWidgets('広い画面の手前（899px）：今までどおり4列で2行', (tester) async {
      final rects = await buttonsAt(tester, 899);
      expect(rects.map((r) => r.top).toSet(), hasLength(2));
      expect(rects.first.width, greaterThan(typeButtonMaxWidth));
      await close(tester);
    });
  });

  testWidgets('UT-HM-10 今日の記録を押すと、その記録の詳細へ進む', (tester) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await show(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, '水'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ミケ　水'));
    await tester.pumpAndSettle();

    final id = (await records()).single.id;
    expect(find.text('詳細：$id'), findsOneWidget);
    await close(tester);
  });
}
