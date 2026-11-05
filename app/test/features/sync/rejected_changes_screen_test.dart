import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/auth_repository.dart';
import 'package:meowscope/features/sync/presentation/rejected_changes_screen.dart';
import 'package:meowscope/features/sync/presentation/sync_controller.dart';

import '../../helpers/test_db.dart';

/// 同期を呼ばれた回数を数える（通信はしない）
class _FakeSync extends SyncController {
  static var calls = 0;

  @override
  Future<void> sync() async => calls++;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = memoryDatabase();
    _FakeSync.calls = 0;
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await db
        .into(db.recordTypes)
        .insert(
          RecordTypesCompanion.insert(
            id: 't1',
            createdAt: testTime,
            updatedAt: testTime,
            householdId: 'h1',
            name: 'ご飯',
            kind: 'food',
          ),
        );
    await db
        .into(db.records)
        .insert(
          RecordsCompanion.insert(
            id: 'r1',
            createdAt: testTime,
            updatedAt: testTime,
            catId: 'c1',
            recordTypeId: 't1',
            recordedAt: DateTime(2026, 11, 5, 8, 10),
            authorName: 'はる',
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> reject(String table, String id, String reason) => db
      .into(db.rejectedChanges)
      .insert(
        RejectedChangesCompanion.insert(
          userId: 'u1',
          targetTable: table,
          rowId: id,
          reason: reason,
          field: Value(reason == 'invalid' ? 'level' : null),
          rejectedAt: DateTime(2026, 11, 5, 9, 30),
        ),
      );

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const RejectedChangesScreen(),
        ),
        GoRoute(
          path: '/records/:id',
          builder: (context, state) =>
              Text('記録の詳細：${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/contact',
          builder: (context, state) => const Text('問い合わせの画面'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authUserProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(id: 'u1', name: 'はる')),
          ),
          syncControllerProvider.overrideWith(_FakeSync.new),
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

  testWidgets('UT-RJ-08 送れなかった変更がなければ、その旨を出す', (tester) async {
    await show(tester);
    expect(find.text('送れなかった変更はありません'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-RJ-09 何の変更か・日時・原因・対応を出し、記録は開ける', (tester) async {
    await reject('records', 'r1', 'invalid');
    await show(tester);

    expect(find.text('11/05 08:10 ミケのご飯'), findsOneWidget);
    expect(find.text('送れなかった日時：11/05 09:30'), findsOneWidget);
    expect(find.text('「量」の内容が決まりに合いません'), findsOneWidget);
    expect(find.text('「量」を直してから「送り直す」を押してください'), findsOneWidget);

    await tester.tap(find.text('記録を開く'));
    await tester.pumpAndSettle();
    expect(find.text('記録の詳細：r1'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-RJ-10 送り直すと、同期待ちに戻して一覧から外し、すぐ同期する', (tester) async {
    await reject('records', 'r1', 'unknown_table');
    await show(tester);

    await tester.tap(find.widgetWithText(FilledButton, '送り直す'));
    await tester.pumpAndSettle();

    expect(find.text('送れなかった変更はありません'), findsOneWidget);
    expect(await db.select(db.pendingChanges).get(), hasLength(1));
    expect(_FakeSync.calls, 1);
    await close(tester);
  });

  testWidgets('UT-RJ-11 権限がないときは送り直しを出さない。一覧から消すは確認してから消す', (tester) async {
    await reject('cats', 'c1', 'forbidden');
    await show(tester);
    expect(find.widgetWithText(FilledButton, '送り直す'), findsNothing);
    expect(find.text('記録を開く'), findsNothing);

    // キャンセルなら消さない
    await tester.tap(find.text('一覧から消す'));
    await tester.pumpAndSettle();
    expect(find.text('この変更はサーバーに送りません。端末の内容はそのまま残ります'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('猫：ミケ'), findsOneWidget);

    await tester.tap(find.text('一覧から消す'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '消す'));
    await tester.pumpAndSettle();
    expect(find.text('送れなかった変更はありません'), findsOneWidget);
    expect(await db.select(db.pendingChanges).get(), isEmpty);
    await close(tester);
  });

  testWidgets('UT-RJ-12 解決しないときは問い合わせの画面へ進める', (tester) async {
    await show(tester);
    await tester.tap(find.text('解決しないときは問い合わせる'));
    await tester.pumpAndSettle();
    expect(find.text('問い合わせの画面'), findsOneWidget);
    await close(tester);
  });
}
