import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/household/data/household_repository.dart';
import 'package:meowscope/features/records/data/record_repository.dart';
import 'package:meowscope/features/records/domain/record_kind.dart';
import 'package:meowscope/features/records/presentation/record_detail_screen.dart';
import 'package:meowscope/features/records/presentation/record_edit_screen.dart';

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
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await repo.addStandardTypes('h1');
  });

  tearDown(() => db.close());

  /// 指定した種類の記録を1件作る
  Future<String> addRecord(RecordKind kind) async {
    // ウィジェットのテストの中では DB の見張り（stream）が進まないので、直接読む
    final type = await (db.select(
      db.recordTypes,
    )..where((t) => t.kind.equals(kind.name))).getSingle();
    return repo.addRecord(catId: 'c1', recordTypeId: type.id, author: _author);
  }

  Future<RecordRow> stored() => db.select(db.records).getSingle();

  /// 一覧の代わりの画面の上に、指定した画面を開く
  Future<void> show(WidgetTester tester, String location) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('一覧'),
          routes: [
            GoRoute(
              path: 'records/:id',
              builder: (context, state) =>
                  RecordDetailScreen(recordId: state.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) =>
                      RecordEditScreen(recordId: state.pathParameters['id']!),
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

  group('記録の詳細入力（S-12）', () {
    testWidgets('UT-RS-01 ご飯は量とメモを出し、体重は出さない', (tester) async {
      final id = await addRecord(RecordKind.food);
      await show(tester, '/records/$id/edit');

      expect(find.text('量'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'メモ'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '体重'), findsNothing);
      await close(tester);
    });

    testWidgets('UT-RS-02 体重は体重の欄を出し、量は出さない', (tester) async {
      final id = await addRecord(RecordKind.weight);
      await show(tester, '/records/$id/edit');

      expect(find.widgetWithText(TextFormField, '体重'), findsOneWidget);
      expect(find.text('量'), findsNothing);
      await close(tester);
    });

    testWidgets('UT-RS-03 量とメモを入力して保存し、前の画面へ戻る', (tester) async {
      final id = await addRecord(RecordKind.food);
      await show(tester, '/records/$id/edit');

      await tester.tap(find.text('多い'));
      await tester.enterText(find.widgetWithText(TextFormField, 'メモ'), '完食');
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pumpAndSettle();

      final r = await stored();
      expect(r.level, 'much');
      expect(r.memo, '完食');
      expect(find.text('記録の詳細'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-RS-04 選んだ量をもう一度押すと取り消せる', (tester) async {
      final id = await addRecord(RecordKind.food);
      await show(tester, '/records/$id/edit');

      await tester.tap(find.text('少し'));
      await tester.pump();
      await tester.tap(find.text('少し'));
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pumpAndSettle();

      expect((await stored()).level, isNull);
      await close(tester);
    });

    testWidgets('UT-RS-05 体重を保存する。範囲外なら保存しない', (tester) async {
      final id = await addRecord(RecordKind.weight);
      await show(tester, '/records/$id/edit');
      final field = find.widgetWithText(TextFormField, '体重');

      await tester.enterText(field, '31');
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('0.1〜30 kg で入力してください'), findsOneWidget);
      expect((await stored()).valueNumber, isNull);

      await tester.enterText(field, '4.2');
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pumpAndSettle();
      expect((await stored()).valueNumber, 4.2);
      await close(tester);
    });

    testWidgets('UT-RS-06 日時を選び直して保存する', (tester) async {
      final id = await addRecord(RecordKind.water);
      await show(tester, '/records/$id/edit');
      final before = (await stored()).recordedAt.toLocal();

      // 日時のボタン（写真の追加のボタンより上にある）
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // 時刻の選択は、時と分をそのまま確定する
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pumpAndSettle();

      final after = (await stored()).recordedAt.toLocal();
      expect(after.second, 0);
      expect(after.difference(before).inMinutes.abs(), lessThan(1));
      await close(tester);
    });

    testWidgets('UT-RS-07 日付の選択を閉じたら日時は変わらない', (tester) async {
      final id = await addRecord(RecordKind.water);
      await show(tester, '/records/$id/edit');
      final label = tester
          .widget<Text>(
            find.descendant(
              of: find.byType(OutlinedButton).first,
              matching: find.byType(Text),
            ),
          )
          .data;

      // 日時のボタン（写真の追加のボタンより上にある）
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, label!), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-RS-08 記録がなければ、見つからないと表示する', (tester) async {
      await show(tester, '/records/none/edit');

      expect(find.text('この記録は見つかりません'), findsOneWidget);
      await close(tester);
    });
  });

  group('記録の詳細と編集（S-22）', () {
    testWidgets('UT-RS-09 猫・項目・投稿者と、入力した詳細を出す', (tester) async {
      final id = await addRecord(RecordKind.weight);
      await repo.updateRecord(
        id: id,
        recordedAt: DateTime(2026, 11, 2, 12),
        level: null,
        valueNumber: 4.2,
        memo: '毛玉のよう',
        author: _author,
      );
      await show(tester, '/records/$id');

      expect(find.text('ミケ　体重'), findsOneWidget);
      expect(find.text('11/02 12:00　投稿者：はる'), findsOneWidget);
      expect(find.text('4.2 kg'), findsOneWidget);
      expect(find.text('毛玉のよう'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-RS-10 量を出す。詳細がなくても「詳細はまだありません」は出さない', (tester) async {
      final id = await addRecord(RecordKind.food);
      await show(tester, '/records/$id');
      expect(find.text('ミケ　ご飯'), findsOneWidget);
      expect(find.text('詳細はまだありません'), findsNothing);

      await repo.updateRecord(
        id: id,
        recordedAt: DateTime(2026, 11, 2, 12),
        level: 'normal',
        valueNumber: null,
        memo: null,
        author: _author,
      );
      await tester.pumpAndSettle();
      expect(find.text('普通'), findsOneWidget);
      expect(find.text('詳細はまだありません'), findsNothing);
      await close(tester);
    });

    testWidgets('UT-RS-11 「編集」で詳細入力へ進む', (tester) async {
      final id = await addRecord(RecordKind.food);
      await show(tester, '/records/$id');

      await tester.tap(find.widgetWithText(TextButton, '編集'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, '保存'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-RS-12 削除の確認は左に削除、右にキャンセル（BR-29）。キャンセルなら残す', (tester) async {
      final id = await addRecord(RecordKind.food);
      await show(tester, '/records/$id');

      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final delete = find.descendant(of: dialog, matching: find.text('削除'));
      final cancel = find.descendant(of: dialog, matching: find.text('キャンセル'));
      expect(
        tester.getCenter(delete).dx,
        lessThan(tester.getCenter(cancel).dx),
      );

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect((await stored()).deletedAt, isNull);
      expect(find.text('記録の詳細'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-RS-13 削除を選ぶと消して、前の画面へ戻る', (tester) async {
      final id = await addRecord(RecordKind.food);
      await show(tester, '/records/$id');

      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('削除'),
        ),
      );
      await tester.pumpAndSettle();

      expect((await stored()).deletedAt, isNotNull);
      expect(find.text('一覧'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-RS-14 記録がなければ、見つからないと表示する', (tester) async {
      await show(tester, '/records/none');

      expect(find.text('この記録は見つかりません'), findsOneWidget);
      await close(tester);
    });
  });
}
