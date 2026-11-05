import 'package:dio/dio.dart';
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

  testWidgets('UT-AU-28 ログインに困ったら（S-07）：再発行は S-03 を開き、問い合わせは S-06 を開く', (
    tester,
  ) async {
    await start(tester);

    await tester.tap(find.text('ログインに困ったら'));
    await tester.pumpAndSettle();
    expect(find.text('準備中'), findsNothing);
    await tester.tap(find.text('パスワード再発行'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '確認コードを送る'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('問い合わせ'));
    await tester.pumpAndSettle();
    expect(find.text('ログを保存する'), findsOneWidget);
    await close(tester);
  });

  group('S-03 パスワード再設定', () {
    Future<void> openReset(WidgetTester tester) async {
      await start(tester);
      await tester.tap(find.text('ログインに困ったら'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('パスワード再発行'));
      await tester.pumpAndSettle();
    }

    Future<void> requestCode(WidgetTester tester) async {
      await tester.enterText(field('メールアドレス'), 'haru@example.com');
      await tester.tap(find.widgetWithText(OutlinedButton, '確認コードを送る'));
      await tester.pumpAndSettle();
    }

    testWidgets('UT-PR-08 メールアドレスの誤りは送らない。正しければ送り、コードと新しいパスワードの欄を出す', (
      tester,
    ) async {
      server.on(
        'POST',
        '/auth/password-reset/request',
        (r) => const FakeResponse(202),
      );
      await openReset(tester);
      expect(field('確認コード（6桁）'), findsNothing);

      await tester.tap(find.widgetWithText(OutlinedButton, '確認コードを送る'));
      await tester.pumpAndSettle();
      expect(find.text('メールアドレスを入力してください'), findsOneWidget);
      expect(server.requests, isEmpty);

      await requestCode(tester);
      expect(server.sentTo('/auth/password-reset/request').single.data, {
        'email': 'haru@example.com',
      });
      expect(find.textContaining('確認コードを送りました'), findsOneWidget);
      expect(field('確認コード（6桁）'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '確認コードを送り直す'), findsOneWidget);
      await close(tester);
    });

    testWidgets(
      'UT-PR-09 境界値：コードは6桁の数字だけ（5桁は送らない）。パスワードは8文字から。正しければ変えてログインする',
      (tester) async {
        server.on(
          'POST',
          '/auth/password-reset/request',
          (r) => const FakeResponse(202),
        );
        server.on(
          'POST',
          '/auth/password-reset/confirm',
          (r) => FakeResponse(200, authBody()),
        );
        await openReset(tester);
        await requestCode(tester);

        await tester.enterText(field('確認コード（6桁）'), '12345');
        await tester.enterText(field('新しいパスワード（8〜64文字）'), 'Short1!');
        await tester.tap(find.widgetWithText(FilledButton, 'パスワードを変更'));
        await tester.pumpAndSettle();
        expect(find.text('確認コードは6桁の数字です'), findsOneWidget);
        expect(server.sentTo('/auth/password-reset/confirm'), isEmpty);

        // 数字でない文字は入らず、7桁目も入らない
        await tester.enterText(field('確認コード（6桁）'), '12a3456789');
        expect(
          tester.widget<TextFormField>(field('確認コード（6桁）')).controller!.text,
          '123456',
        );
        await tester.enterText(field('新しいパスワード（8〜64文字）'), 'Passw0rd');
        await tester.tap(find.widgetWithText(FilledButton, 'パスワードを変更'));
        await tester.pumpAndSettle();

        expect(server.sentTo('/auth/password-reset/confirm').single.data, {
          'email': 'haru@example.com',
          'code': '123456',
          'newPassword': 'Passw0rd',
        });
        expect(tokens.tokens, isNotNull);
        expect(find.text('パスワード再設定'), findsNothing);
        await close(tester);
      },
    );

    testWidgets('UT-PR-10 異常系：コードの誤りは案内を出す。つながらないときは通信の文を出す', (tester) async {
      server.on(
        'POST',
        '/auth/password-reset/request',
        (r) => const FakeResponse(202),
      );
      server.on(
        'POST',
        '/auth/password-reset/confirm',
        (r) => const FakeResponse(400, {'code': 'INVALID_RESET_CODE'}),
      );
      await openReset(tester);
      await requestCode(tester);
      await tester.enterText(field('確認コード（6桁）'), '123456');
      await tester.enterText(field('新しいパスワード（8〜64文字）'), 'Passw0rd!');
      await tester.tap(find.widgetWithText(FilledButton, 'パスワードを変更'));
      await tester.pumpAndSettle();
      expect(find.textContaining('確認コードが違うか、期限が切れています'), findsOneWidget);
      expect(tokens.tokens, isNull);

      server.on(
        'POST',
        '/auth/password-reset/request',
        (r) => throw DioException.connectionError(
          requestOptions: r,
          reason: 'offline',
        ),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, '確認コードを送り直す'));
      await tester.pumpAndSettle();
      expect(find.textContaining('サーバーにつながりません'), findsOneWidget);
      await close(tester);
    });
  });
}
