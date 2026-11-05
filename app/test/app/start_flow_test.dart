import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/main.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeServer server;
  late MemoryTokenStore tokens;

  setUp(() {
    db = memoryDatabase();
    server = FakeServer()
      ..on('POST', '/auth/register', (r) => FakeResponse(201, authBody()))
      ..on('POST', '/auth/logout', (r) => const FakeResponse(204));
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

  Future<void> register(WidgetTester tester) async {
    await tester.tap(find.text('新規アカウント作成'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '名前'), 'はる');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'メールアドレス'),
      'haru@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'パスワード（8〜64文字）'),
      'Passw0rd!',
    );
    await tester.tap(find.widgetWithText(FilledButton, '登録する'));
    await tester.pumpAndSettle();
  }

  Future<void> createHousehold(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'おうちの名前'), 'みけ家');
    await tester.tap(find.widgetWithText(FilledButton, '新しいおうちを作る'));
    await tester.pumpAndSettle();
  }

  testWidgets('UT-ST-01 ログインしていなければ、ログイン（S-01）を出す', (tester) async {
    await start(tester);

    expect(find.text('MeowScope'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ログイン'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-ST-02 新規登録の後はおうちの作成を出し、おうちの名前が空欄なら作らない', (tester) async {
    await start(tester);
    await register(tester);
    expect(find.text('おうちを準備します'), findsOneWidget);
    // 名前は新規登録へ移したので、S-04 にはない
    expect(find.widgetWithText(TextFormField, 'あなたの名前'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '新しいおうちを作る'));
    await tester.pumpAndSettle();

    expect(find.text('おうちの名前を入力してください'), findsOneWidget);
    expect(await db.select(db.households).get(), isEmpty);
    await close(tester);
  });

  testWidgets('UT-ST-03 新規登録 → おうちの作成 → 猫の登録 → 記録までの流れ。投稿者名は登録の名前', (
    tester,
  ) async {
    await start(tester);
    await register(tester);
    await createHousehold(tester);
    expect(find.text('猫を登録しましょう'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), 'ミケ');
    await tester.tap(find.widgetWithText(FilledButton, '登録する'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'みけ家'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
    await tester.pumpAndSettle();
    expect(find.text('ミケ　ご飯'), findsOneWidget);
    final record = await db.select(db.records).getSingle();
    expect(record.authorName, 'はる');
    expect(record.authorId, 'u1');
    await close(tester);
  });

  testWidgets('UT-ST-04 次に開いたときは、作ったおうちのホームを出す', (tester) async {
    await start(tester);
    await register(tester);
    await createHousehold(tester);
    await close(tester);

    await start(tester);

    expect(find.widgetWithText(AppBar, 'みけ家'), findsOneWidget);
    expect(find.text('猫が登録されていません'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-ST-05 設定のアカウントからログアウトすると、ログインに戻る', (tester) async {
    await start(tester);
    await register(tester);
    await createHousehold(tester);
    // 猫の登録を飛ばしてホームへ
    await close(tester);
    await start(tester);

    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('アカウント'));
    await tester.pumpAndSettle();
    expect(find.text('はる'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'ログアウト'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'ログイン'), findsOneWidget);
    expect(tokens.tokens, isNull);
    expect(server.sentTo('/auth/logout'), hasLength(1));
    await close(tester);
  });
}
