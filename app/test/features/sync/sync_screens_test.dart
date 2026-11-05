import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/features/sync/presentation/sync_status_screen.dart';
import 'package:meowscope/main.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeServer server;
  late MemoryTokenStore tokens;
  var syncCalls = 0;

  setUp(() async {
    db = memoryDatabase();
    syncCalls = 0;
    server = FakeServer()
      ..on('POST', '/auth/logout', (r) => const FakeResponse(204))
      ..on('POST', '/sync', (r) {
        syncCalls++;
        return const FakeResponse(200, {
          'results': [],
          'changes': [],
          'nextSeq': 1,
          'hasMore': false,
          'fullResyncRequired': false,
        });
      });
    tokens = MemoryTokenStore()
      ..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    // ログイン済みで、おうちを選んだ状態
    await addHousehold(db, 'h1');
    await db.batch(
      (b) => b.insertAll(db.appStates, [
        AppStatesCompanion.insert(key: 'session.userId', value: 'u1'),
        AppStatesCompanion.insert(key: 'session.userName', value: 'はる'),
        AppStatesCompanion.insert(key: 'session.householdId', value: 'h1'),
      ]),
    );
  });
  tearDown(() => db.close());

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(fakeApiClient(server, tokens)),
        ],
        child: const MeowScopeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> openStatus(WidgetTester tester) async {
    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('同期の状態'));
    await tester.pumpAndSettle();
  }

  testWidgets('UT-SY-19 ホームを開くと同期し、上部に最終同期の時刻を出す', (tester) async {
    await start(tester);

    expect(syncCalls, 1);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expect(find.text('未同期'), findsNothing);
    await close(tester);
  });

  testWidgets('UT-SY-20 実行中は5分おきに同期し、バックグラウンドへ移るときも同期する（F-OF-03）', (
    tester,
  ) async {
    await start(tester);
    expect(syncCalls, 1);

    await tester.pump(const Duration(minutes: 4, seconds: 59));
    await tester.pumpAndSettle();
    expect(syncCalls, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(syncCalls, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(syncCalls, 3);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await close(tester);
  });

  testWidgets('UT-SY-21 同期の状態（S-46）：未送信の件数（同じ行は1件）を出し、「今すぐ同期」で送る', (
    tester,
  ) async {
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await start(tester);
    // 同期の後に変更を2回（同じ猫）
    for (var i = 0; i < 2; i++) {
      await db
          .into(db.pendingChanges)
          .insert(
            PendingChangesCompanion.insert(
              userId: 'u1',
              targetTable: 'cats',
              rowId: 'c1',
              operation: 'upsert',
              payload: '{}',
            ),
          );
    }
    await openStatus(tester);

    expect(find.text('1件'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '今すぐ同期'));
    await tester.pumpAndSettle();

    expect(syncCalls, 2);
    expect(find.text('0件'), findsOneWidget);
    expect(find.text('まだ同期していません'), findsNothing);
    await close(tester);
  });

  testWidgets('UT-SY-22 失敗したらホームの印を変え、S-46 に理由と、送れなかった件数を出す。押すと S-48 へ進む', (
    tester,
  ) async {
    server.on(
      'POST',
      '/sync',
      (r) => const FakeResponse(500, {
        'code': 'INTERNAL_ERROR',
        'requestId': 'req-5',
      }),
    );
    for (final id in ['r1', 'r2', 'r3']) {
      await db
          .into(db.rejectedChanges)
          .insert(
            RejectedChangesCompanion.insert(
              userId: 'u1',
              targetTable: 'records',
              rowId: id,
              reason: 'invalid',
              rejectedAt: DateTime.utc(2026, 11, 5),
            ),
          );
    }
    await start(tester);

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('未同期'), findsOneWidget);
    await openStatus(tester);

    expect(find.text('前回の同期に失敗しました'), findsOneWidget);
    expect(find.textContaining('問い合わせ番号：req-5'), findsOneWidget);
    expect(find.text('送れなかった変更'), findsOneWidget);
    expect(find.text('3件'), findsOneWidget);

    // 押すと、どの変更かと対応の案内（S-48）へ進む
    await tester.tap(find.text('送れなかった変更'));
    await tester.pumpAndSettle();
    expect(find.text('削除された記録'), findsNWidgets(3));
    await close(tester);
  });

  testWidgets('UT-SY-23 ログインの期限が切れたら S-46 で案内し、ログインし直せる（記録は残す）', (
    tester,
  ) async {
    tokens.tokens = null;
    await start(tester);
    await openStatus(tester);

    expect(find.text('ログインの期限が切れました'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'ログインし直す'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'ログイン'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-SY-24 ホームの同期の印を押すと同期する。同時に押しても1回だけ（同時に1つだけ）', (tester) async {
    await start(tester);
    expect(syncCalls, 1);

    final indicator = find.byType(SyncIndicator);
    await tester.tap(indicator);
    await tester.tap(indicator);
    await tester.pumpAndSettle();

    expect(syncCalls, 2);
    await close(tester);
  });

  testWidgets('UT-SY-25 おうちを選んでいなくても、同期でサーバーのおうちが見つかればホームを出す（機種変更）', (
    tester,
  ) async {
    await (db.delete(
      db.appStates,
    )..where((s) => s.key.equals('session.householdId'))).go();
    server.on(
      'POST',
      '/sync',
      (r) => const FakeResponse(200, {
        'results': [],
        'changes': [
          {
            'table': 'household_members',
            'id': 'm1',
            'seq': 1,
            'updatedAt': '2026-11-03T00:00:00Z',
            'deletedAt': null,
            'data': {'householdId': 'h1', 'userId': 'u1', 'displayName': 'はる'},
          },
        ],
        'nextSeq': 1,
        'hasMore': false,
        'fullResyncRequired': false,
      }),
    );

    await start(tester);

    expect(find.widgetWithText(AppBar, 'ホーム'), findsOneWidget);
    await close(tester);
  });

  test('UT-SY-26 同期の時刻の表示：未同期／月日と時刻を2けたで', () {
    expect(formatSyncTime(null), 'まだ同期していません');
    expect(formatSyncTime(DateTime(2026, 1, 2, 3, 4)), '01/02 03:04');
    expect(formatSyncTime(DateTime(2026, 11, 30, 23, 59)), '11/30 23:59');
  });
}
