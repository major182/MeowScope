import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/api/api_error.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/account_repository.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/main.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeServer server;
  late MemoryTokenStore tokens;

  Future<void> member(
    String id,
    String? userId,
    String name, {
    DateTime? deletedAt,
  }) => db
      .into(db.householdMembers)
      .insert(
        HouseholdMembersCompanion.insert(
          id: id,
          createdAt: testTime,
          updatedAt: testTime,
          householdId: 'h1',
          userId: Value(userId),
          displayName: Value(name),
          deletedAt: Value(deletedAt),
        ),
      );

  Future<Map<String, String>> states() async => {
    for (final s in await db.select(db.appStates).get()) s.key: s.value,
  };

  setUp(() async {
    db = memoryDatabase();
    server = FakeServer()
      ..on(
        'POST',
        '/sync',
        (r) => const FakeResponse(200, {
          'results': [],
          'changes': [],
          'nextSeq': 1,
          'hasMore': false,
          'fullResyncRequired': false,
        }),
      );
    tokens = MemoryTokenStore()
      ..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    await addHousehold(db, 'h1');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await member('m1', 'u1', 'はる');
    await db.batch(
      (b) => b.insertAll(db.appStates, [
        AppStatesCompanion.insert(key: 'session.userId', value: 'u1'),
        AppStatesCompanion.insert(key: 'session.userName', value: 'はる'),
        AppStatesCompanion.insert(key: 'session.householdId', value: 'h1'),
        AppStatesCompanion.insert(key: 'household.u1', value: 'h1'),
        AppStatesCompanion.insert(key: 'settings.weekStart', value: 'monday'),
      ]),
    );
  });
  tearDown(() => db.close());

  group('アカウントとおうちの管理（リポジトリ）', () {
    late AccountRepository repo;

    setUp(
      () => repo = AccountRepository(db, fakeApiClient(server, tokens), tokens),
    );

    test('UT-MG-01 メンバー：今のメンバーだけを名前の順に出す（抜けた人・退会した人は出さない）', () async {
      await member('m2', 'u2', 'あき');
      await member('m3', 'u3', 'ふゆ', deletedAt: testTime);
      await member('m4', null, '退会した人');

      final members = await repo.watchMembers('h1').first;

      expect(members.map((m) => m.name), ['あき', 'はる']);
    });

    test('UT-MG-02 おうちの名前を変え、前後の空白を除いて同期待ちに入れる', () async {
      await repo.renameHousehold(
        householdId: 'h1',
        userId: 'u1',
        name: ' たま家 ',
      );

      expect(await repo.watchHouseholdName('h1').first, 'たま家');
      final pending = await db.select(db.pendingChanges).getSingle();
      expect(
        (pending.targetTable, pending.rowId, pending.operation),
        ('households', 'h1', 'upsert'),
      );
    });

    test('UT-MG-03 表示名を変えると、セッションの名前も変わる。失敗は ApiError', () async {
      server.on(
        'PATCH',
        '/me',
        (r) => const FakeResponse(200, {
          'id': 'u1',
          'email': 'haru@example.com',
          'displayName': 'はるか',
        }),
      );
      await repo.rename(' はるか ');
      expect((server.sentTo('/me').single.data as Map)['displayName'], 'はるか');
      expect((await states())['session.userName'], 'はるか');

      server.on('PATCH', '/me', (r) => const FakeResponse.offline());
      await expectLater(repo.rename('x'), throwsA(isA<ApiError>()));
    });

    test('UT-MG-04 パスワードの変更：新しいトークンに替える。今のパスワードが違えば 403 の ApiError', () async {
      server.on(
        'PUT',
        '/me/password',
        (r) => const FakeResponse(200, {
          'accessToken': 'a2',
          'refreshToken': 'r2',
          'expiresIn': 900,
        }),
      );
      await repo.changePassword(current: 'old', next: 'NewPassw0rd');
      expect(server.sentTo('/me/password').single.data, {
        'currentPassword': 'old',
        'newPassword': 'NewPassw0rd',
      });
      expect(tokens.tokens?.refreshToken, 'r2');

      server.on(
        'PUT',
        '/me/password',
        (r) => const FakeResponse(403, {'code': 'FORBIDDEN'}),
      );
      await expectLater(
        repo.changePassword(current: 'x', next: 'NewPassw0rd'),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 403)),
      );
      expect(tokens.tokens?.refreshToken, 'r2');
    });

    test('UT-MG-05 抜ける：選んだ内容を送り、端末からそのおうちのデータと選択を消す', () async {
      server.on(
        'POST',
        '/households/h1/leave',
        (r) => const FakeResponse(200, {'householdDeleted': false}),
      );

      await repo.leaveHousehold(
        userId: 'u1',
        householdId: 'h1',
        keepRecords: false,
      );

      expect(server.sentTo('/households/h1/leave').single.data, {
        'keepRecords': false,
      });
      expect(await db.select(db.cats).get(), isEmpty);
      expect(await db.select(db.households).get(), isEmpty);
      final s = await states();
      expect(s['session.householdId'], isNull);
      expect(s['household.u1'], isNull);
      expect(s['session.userId'], 'u1');
    });

    test('UT-MG-06 異常系：抜けるのに失敗したら、端末のデータを残す', () async {
      server.on(
        'POST',
        '/households/h1/leave',
        (r) => const FakeResponse.offline(),
      );

      await expectLater(
        repo.leaveHousehold(userId: 'u1', householdId: 'h1', keepRecords: true),
        throwsA(isA<ApiError>().having((e) => e.isOffline, 'offline', true)),
      );
      expect(await db.select(db.cats).get(), hasLength(1));
    });

    test('UT-MG-07 退会：送った後に、端末のデータ・トークン・自分の同期待ちを消す。設定と他の人の同期待ちは残す', () async {
      server.on('DELETE', '/me', (r) => const FakeResponse(204));
      for (final user in ['u1', 'other']) {
        await db
            .into(db.pendingChanges)
            .insert(
              PendingChangesCompanion.insert(
                userId: user,
                targetTable: 'cats',
                rowId: 'c1',
                operation: 'upsert',
                payload: '{}',
              ),
            );
      }

      await repo.deleteAccount(userId: 'u1', keepRecords: true);

      expect(server.sentTo('/me').single.data, {'keepRecords': true});
      expect(tokens.tokens, isNull);
      expect(await db.select(db.cats).get(), isEmpty);
      expect((await db.select(db.pendingChanges).get()).map((p) => p.userId), [
        'other',
      ]);
      expect(await states(), {'settings.weekStart': 'monday'});
    });

    test('UT-MG-08 異常系：退会に失敗したら何も消さない', () async {
      server.on(
        'DELETE',
        '/me',
        (r) => const FakeResponse(500, {'requestId': 'q1'}),
      );
      await expectLater(
        repo.deleteAccount(userId: 'u1', keepRecords: false),
        throwsA(isA<ApiError>()),
      );
      expect(tokens.tokens, isNotNull);
      expect(await db.select(db.cats).get(), hasLength(1));
    });
  });

  group('画面', () {
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

    Future<void> open(WidgetTester tester, String label) async {
      await tester.tap(find.text('設定').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('UT-MG-09 S-42：おうち名とメンバーを出し、名前を保存できる。招待は準備中', (tester) async {
      await member('m2', 'u2', 'なつ');
      await start(tester);
      await open(tester, 'おうちの管理');

      expect(find.widgetWithText(TextField, 'みけ家'), findsOneWidget);
      expect(find.text('はる'), findsOneWidget);
      expect(find.text('なつ'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'メールで招待する'))
            .enabled,
        isFalse,
      );

      await tester.enterText(find.byType(TextField), 'たま家');
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('おうちの名前を保存しました'), findsOneWidget);
      expect((await db.select(db.households).getSingle()).name, 'たま家');
      await close(tester);
    });

    testWidgets('UT-MG-10 S-42：ほかにメンバーがいれば「残す・消す」を選んで抜け、おうちの作成へ戻る', (
      tester,
    ) async {
      await member('m2', 'u2', 'なつ');
      server.on(
        'POST',
        '/households/h1/leave',
        (r) => const FakeResponse(200, {'householdDeleted': false}),
      );
      await start(tester);
      await open(tester, 'おうちの管理');

      await tester.tap(find.text('おうちを抜ける'));
      await tester.pumpAndSettle();
      expect(find.text('おうちの記録を残しますか？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '残す'));
      await tester.pumpAndSettle();

      expect(server.sentTo('/households/h1/leave').single.data, {
        'keepRecords': true,
      });
      expect(find.text('おうちを準備します'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-MG-11 S-42：最後の1人はおうちごと消す確認を出す（BR-19）。キャンセルなら抜けない', (
      tester,
    ) async {
      await start(tester);
      await open(tester, 'おうちの管理');

      await tester.tap(find.text('おうちを抜ける'));
      await tester.pumpAndSettle();
      expect(find.text('おうちと記録をすべて削除しますか？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'キャンセル'));
      await tester.pumpAndSettle();

      expect(server.sentTo('/households/h1/leave'), isEmpty);
      await close(tester);
    });

    testWidgets('UT-MG-12 S-42：抜けるのに失敗したら理由を出し、画面に残る', (tester) async {
      server.on(
        'POST',
        '/households/h1/leave',
        (r) => const FakeResponse.offline(),
      );
      await start(tester);
      await open(tester, 'おうちの管理');

      await tester.tap(find.text('おうちを抜ける'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();

      expect(find.text('サーバーにつながりません。通信の状態を確かめてください'), findsOneWidget);
      expect(find.text('おうちの管理'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-MG-13 S-45：名前を保存する。空なら保存しない', (tester) async {
      server.on(
        'PATCH',
        '/me',
        (r) => const FakeResponse(200, {'displayName': 'はるか'}),
      );
      await start(tester);
      await open(tester, 'アカウント');

      await tester.enterText(find.byType(TextFormField), ' ');
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('名前を入力してください'), findsOneWidget);
      expect(server.sentTo('/me'), isEmpty);

      await tester.enterText(find.byType(TextFormField), 'はるか');
      await tester.tap(find.widgetWithText(TextButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('名前を保存しました'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-MG-14 S-45：パスワードの変更。入力の誤りは送らず、今のパスワードが違えばその旨を出す', (
      tester,
    ) async {
      server.on(
        'PUT',
        '/me/password',
        (r) => const FakeResponse(403, {'code': 'FORBIDDEN'}),
      );
      await start(tester);
      await open(tester, 'アカウント');

      await tester.tap(find.text('パスワードを変更'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('変更する'));
      await tester.pumpAndSettle();
      expect(find.text('今のパスワードを入力してください'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, '今のパスワード'),
        'wrongpass',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '新しいパスワード（8〜64文字）'),
        'NewPassw0rd',
      );
      await tester.tap(find.text('変更する'));
      await tester.pumpAndSettle();
      expect(find.text('今のパスワードが違います'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-MG-15 S-45：退会は「残す・消す」と削除の確認の後に送り、ログインへ戻る。確認でキャンセルなら送らない', (
      tester,
    ) async {
      server.on('DELETE', '/me', (r) => const FakeResponse(204));
      await start(tester);
      await open(tester, 'アカウント');

      await tester.tap(find.text('アカウントを削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '消す'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'キャンセル'));
      await tester.pumpAndSettle();
      expect(server.sentTo('/me'), isEmpty);

      await tester.tap(find.text('アカウントを削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '消す'));
      await tester.pumpAndSettle();
      expect(find.text('アカウントを削除しますか？'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();

      expect(server.sentTo('/me').single.data, {'keepRecords': false});
      expect(find.widgetWithText(FilledButton, 'ログイン'), findsOneWidget);
      await close(tester);
    });
  });
}
