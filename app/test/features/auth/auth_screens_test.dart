import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/main.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeServer server;
  late MemoryTokenStore tokens;

  setUp(() {
    db = memoryDatabase();
    server = FakeServer();
    tokens = MemoryTokenStore();
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

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> login(
    WidgetTester tester, {
    String password = 'Passw0rd!',
  }) async {
    await tester.enterText(field('メールアドレス'), 'haru@example.com');
    await tester.enterText(field('パスワード'), password);
    await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
    await tester.pumpAndSettle();
  }

  testWidgets('UT-AU-22 ログイン：空欄なら送らない', (tester) async {
    await start(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
    await tester.pumpAndSettle();

    expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsOneWidget);
    expect(server.requests, isEmpty);
    await close(tester);
  });

  testWidgets('UT-RW-02 広い画面（1280px）のログイン：入力欄とボタンは 640px で、中央に寄せる', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await start(tester);

    final email = tester.getRect(field('メールアドレス'));
    final button = tester.getRect(find.widgetWithText(FilledButton, 'ログイン'));
    expect((email.width, email.left), (640, 320));
    expect((button.width, button.left), (640, 320));
    await close(tester);
  });

  testWidgets('UT-AU-23 ログイン：成功するとおうちの作成へ進む', (tester) async {
    server.on('POST', '/auth/login', (r) => FakeResponse(200, authBody()));
    await start(tester);

    await login(tester);

    expect(find.text('おうちを準備します'), findsOneWidget);
    expect(tokens.tokens?.accessToken, 'access-1');
    await close(tester);
  });

  for (final (status, body, text) in [
    (401, {'code': 'UNAUTHORIZED'}, 'メールアドレスかパスワードが違います'),
    (429, {'code': 'TOO_MANY_REQUESTS'}, 'ログインの失敗が続いたため、しばらく待ってからやり直してください'),
    (0, null, 'サーバーにつながりません。通信の状態を確かめてください'),
    (
      500,
      {'code': 'INTERNAL_ERROR', 'requestId': 'req-77'},
      '問題が発生しました。時間をおいてやり直してください（問い合わせ番号：req-77）',
    ),
  ]) {
    testWidgets('UT-AU-24 ログインの失敗（$status）：「$text」を出し、もう一度押せる', (tester) async {
      server.on(
        'POST',
        '/auth/login',
        (r) => status == 0
            ? const FakeResponse.offline()
            : FakeResponse(status, body),
      );
      await start(tester);

      await login(tester);

      expect(find.text(text), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'ログイン'),
      );
      expect(button.onPressed, isNotNull);
      await close(tester);
    });
  }

  testWidgets('UT-AU-25 全角を入れようとすると入力欄を変えず、案内を出す（BR-26）', (tester) async {
    await start(tester);

    await tester.enterText(field('メールアドレス'), 'haru');
    await tester.enterText(field('メールアドレス'), 'haruｈ');
    await tester.pump();

    expect(find.text('haru'), findsOneWidget);
    expect(find.text('全角の文字は使えません。半角で入力してください'), findsOneWidget);

    // 半角を入れ直すと案内は消える
    await tester.enterText(field('メールアドレス'), 'haru@');
    await tester.pump();
    expect(find.text('全角の文字は使えません。半角で入力してください'), findsNothing);
    await close(tester);
  });

  testWidgets('UT-AU-26 新規登録：入力の誤りがあれば送らない', (tester) async {
    await start(tester);
    await tester.tap(find.text('新規アカウント作成'));
    await tester.pumpAndSettle();

    await tester.enterText(field('メールアドレス'), 'haru');
    await tester.enterText(field('パスワード（8〜64文字）'), 'short');
    await tester.tap(find.widgetWithText(FilledButton, '登録する'));
    await tester.pumpAndSettle();

    expect(find.text('名前を入力してください'), findsOneWidget);
    expect(find.text('メールアドレスの形で入力してください'), findsOneWidget);
    expect(find.text('パスワードは8〜64文字で入力してください'), findsOneWidget);
    expect(server.requests, isEmpty);
    await close(tester);
  });

  testWidgets('UT-AU-27 新規登録：登録済みのメールアドレスはその旨を出す', (tester) async {
    server.on(
      'POST',
      '/auth/register',
      (r) => const FakeResponse(409, {'code': 'CONFLICT'}),
    );
    await start(tester);
    await tester.tap(find.text('新規アカウント作成'));
    await tester.pumpAndSettle();

    await tester.enterText(field('名前'), 'はる');
    await tester.enterText(field('メールアドレス'), 'haru@example.com');
    await tester.enterText(field('パスワード（8〜64文字）'), 'Passw0rd!');
    await tester.tap(find.widgetWithText(FilledButton, '登録する'));
    await tester.pumpAndSettle();

    expect(find.text('このメールアドレスはすでに登録されています'), findsOneWidget);
    expect(await db.select(db.appStates).get(), isEmpty);
    await close(tester);
  });

  testWidgets('UT-AU-28 ログインに困ったら（S-07）：再発行は準備中で押せず、問い合わせは S-06 を開く', (
    tester,
  ) async {
    await start(tester);

    await tester.tap(find.text('ログインに困ったら'));
    await tester.pumpAndSettle();

    final reset = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'パスワード再発行'),
    );
    expect(reset.enabled, isFalse);
    expect(find.text('準備中'), findsOneWidget);
    await tester.tap(find.text('問い合わせ'));
    await tester.pumpAndSettle();
    expect(find.text('ログを保存する'), findsOneWidget);
    await close(tester);
  });
}
