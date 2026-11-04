import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/api/api_error.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/account_repository.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/features/auth/domain/credentials.dart';
import 'package:meowscope/main.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

const token = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_abcd';

void main() {
  late AppDatabase db;
  late FakeServer server;
  late MemoryTokenStore tokens;

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
      )
      ..on(
        'POST',
        '/households/h1/invitations',
        (r) => const FakeResponse(201, {
          'token': token,
          'link': 'meowscope://invite?token=$token',
          'expiresAt': '2026-11-04T01:00:00Z',
        }),
      )
      ..on(
        'POST',
        '/invitations/accept',
        (r) => const FakeResponse(200, {'householdId': 'h9'}),
      );
    tokens = MemoryTokenStore()
      ..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    await db.batch(
      (b) => b.insertAll(db.appStates, [
        AppStatesCompanion.insert(key: 'session.userId', value: 'u1'),
        AppStatesCompanion.insert(key: 'session.userName', value: 'はる'),
      ]),
    );
  });
  tearDown(() => db.close());

  test(
    'UT-IV-01 招待の文・リンク・トークンだけのどれからもトークンを取り出す。短い・ないときは null（境界値 19・20文字）',
    () {
      expect(
        extractInviteToken(
          invitationMessage('みけ家', 'meowscope://invite?token=$token'),
        ),
        token,
      );
      expect(extractInviteToken('  $token\n'), token);
      expect(extractInviteToken('a' * 20), 'a' * 20);
      expect(extractInviteToken('a' * 19), isNull);
      expect(extractInviteToken('こんにちは'), isNull);
    },
  );

  group('リポジトリ', () {
    late AccountRepository repo;
    setUp(
      () => repo = AccountRepository(db, fakeApiClient(server, tokens), tokens),
    );

    test('UT-IV-02 招待を作ると、おうちの名前とリンクの入った送る文を返す。失敗は ApiError', () async {
      final message = await repo.createInvitation(
        householdId: 'h1',
        householdName: 'みけ家',
      );
      expect(message, contains('「みけ家」'));
      expect(message, contains('meowscope://invite?token=$token'));
      expect(message, contains('1時間'));

      server.on(
        'POST',
        '/households/h1/invitations',
        (r) => const FakeResponse(404),
      );
      await expectLater(
        repo.createInvitation(householdId: 'h1', householdName: 'みけ家'),
        throwsA(isA<ApiError>()),
      );
    });

    test('UT-IV-03 招待を受けると、そのおうちを選んだ状態にする。使えない招待なら何も変えない', () async {
      server.on('POST', '/invitations/accept', (r) => const FakeResponse(404));
      await expectLater(
        repo.acceptInvitation(userId: 'u1', token: token),
        throwsA(isA<ApiError>()),
      );
      expect((await states())['session.householdId'], isNull);

      server.on(
        'POST',
        '/invitations/accept',
        (r) => const FakeResponse(200, {'householdId': 'h9'}),
      );
      await repo.acceptInvitation(userId: 'u1', token: token);
      expect(server.sentTo('/invitations/accept').last.data, {'token': token});
      final s = await states();
      expect((s['session.householdId'], s['household.u1']), ('h9', 'h9'));
      expect((await db.select(db.households).getSingle()).id, 'h9');
    });
  });

  group('画面', () {
    Future<void> start(WidgetTester tester, {Stream<Uri>? links}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tokenStoreProvider.overrideWithValue(tokens),
            apiClientProvider.overrideWithValue(fakeApiClient(server, tokens)),
          ],
          child: MeowScopeApp(links: links),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }

    testWidgets('UT-IV-04 S-42「リンクで招待する」で招待の文をコピーし、内容を見せる', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await addHousehold(db, 'h1');
      await db
          .into(db.appStates)
          .insert(
            AppStatesCompanion.insert(key: 'session.householdId', value: 'h1'),
          );
      await start(tester);
      await tester.tap(find.text('設定').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('おうちの管理'));
      await tester.pumpAndSettle();
      server.requests.clear();

      await tester.tap(find.text('リンクで招待する'));
      await tester.pumpAndSettle();

      expect(find.text('招待の文をコピーしました'), findsOneWidget);
      expect(copied, contains('meowscope://invite?token=$token'));
      // 先に同期して手元の猫と記録を送ってから、招待を作る
      expect(server.requests.map((r) => r.path), [
        '/sync',
        '/households/h1/invitations',
      ]);
      await close(tester);
    });

    testWidgets('UT-IV-05 S-04「招待されたおうちに参加」に招待の文を貼り付けて参加すると、ホームを出す', (
      tester,
    ) async {
      await start(tester);
      expect(find.text('おうちを準備します'), findsOneWidget);

      await tester.tap(find.text('招待されたおうちに参加'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        invitationMessage('みけ家', 'meowscope://invite?token=$token'),
      );
      server.requests.clear();
      await tester.tap(find.text('参加する'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'ホーム'), findsOneWidget);
      // 参加したらすぐに同期して、おうちの中身を受け取る
      expect(server.requests.map((r) => r.path), [
        '/invitations/accept',
        '/sync',
      ]);
      await close(tester);
    });

    testWidgets('UT-IV-06 異常系：トークンがなければ送らず、使えない招待（404）は作り直しを案内する', (
      tester,
    ) async {
      server.on(
        'POST',
        '/invitations/accept',
        (r) => const FakeResponse(404, {'code': 'NOT_FOUND'}),
      );
      await start(tester);
      await tester.tap(find.text('招待されたおうちに参加'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('参加する'));
      await tester.pumpAndSettle();
      expect(find.text('招待の文かリンクを貼り付けてください'), findsOneWidget);
      expect(server.sentTo('/invitations/accept'), isEmpty);

      await tester.enterText(find.byType(TextField), token);
      await tester.tap(find.text('参加する'));
      await tester.pumpAndSettle();
      expect(find.textContaining('期限切れか、使用済みです'), findsOneWidget);
      await close(tester);
    });

    testWidgets('UT-IV-07 招待のリンクでアプリが開くと、トークンを入れた参加の画面を出す。ほかのリンクは無視する', (
      tester,
    ) async {
      final links = StreamController<Uri>();
      addTearDown(links.close);
      await start(tester, links: links.stream);

      links.add(Uri.parse('https://example.com/?token=$token'));
      await tester.pumpAndSettle();
      expect(find.text('参加する'), findsNothing);

      links.add(Uri.parse('meowscope://invite?token=$token'));
      await tester.pumpAndSettle();
      expect(find.text('参加する'), findsOneWidget);
      expect(find.text(token), findsOneWidget);
      await close(tester);
    });
  });
}
