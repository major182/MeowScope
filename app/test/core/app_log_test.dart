import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/logging/app_log.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/features/settings/presentation/contact_screen.dart';
import 'package:meowscope/features/sync/presentation/sync_controller.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late AppLog log;
  late FakeServer server;
  late MemoryTokenStore tokens;

  setUp(() {
    db = memoryDatabase();
    log = AppLog(db, clock: () => DateTime.utc(2026, 11, 3, 10));
    server = FakeServer();
    tokens = MemoryTokenStore()
      ..tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
  });
  tearDown(() => db.close());

  test('UT-LO-01 メールアドレスを伏せ、2000文字を超えたら切る（境界値 2000・2001）', () async {
    expect(AppLog.sanitize('失敗 haru@example.com です'), '失敗 ***@*** です');
    expect(AppLog.sanitize('a' * 2000), hasLength(2000));
    expect(AppLog.sanitize('a' * 2001), hasLength(2000));
    await log.record('error', 'x natsu@example.jp', requestId: 'req-1');
    final row = await db.select(db.clientLogs).getSingle();
    expect(
      (row.status, row.message, row.requestId),
      ('error', 'x ***@***', 'req-1'),
    );
  });

  test('UT-LO-02 最新の1000件だけを残す（境界値 1000・1001）', () async {
    for (var i = 0; i < 1000; i++) {
      await log.record('info', 'm$i');
    }
    expect(await db.select(db.clientLogs).get(), hasLength(1000));
    await log.record('info', 'last');
    final rows = await db.select(db.clientLogs).get();
    expect(rows, hasLength(1000));
    expect(rows.first.message, 'm1');
    expect(rows.last.message, 'last');
  });

  test('UT-LO-03 100件ずつ送り、送れたものを消す。端末の属性を付ける', () async {
    for (var i = 0; i < 250; i++) {
      await log.record('warning', 'm$i', requestId: i == 0 ? 'req-0' : null);
    }
    server.on('POST', '/client-logs', (r) => const FakeResponse(204));

    await log.send(fakeApiClient(server, tokens));

    final sent = server.sentTo('/client-logs');
    expect(sent.map((r) => ((r.data as Map)['logs'] as List).length), [
      100,
      100,
      50,
    ]);
    final first = ((sent.first.data as Map)['logs'] as List).first as Map;
    expect(first['status'], 'warning');
    expect(first['requestId'], 'req-0');
    expect(first['occurredAt'], '2026-11-03T10:00:00.000Z');
    expect(first.keys, containsAll(['platform', 'appVersion', 'osVersion']));
    expect(await db.select(db.clientLogs).get(), isEmpty);
  });

  test('UT-LO-04 異常系：送れなければ残し、例外を投げない', () async {
    await log.record('error', 'x');
    server.on('POST', '/client-logs', (r) => const FakeResponse.offline());
    await log.send(fakeApiClient(server, tokens));
    expect(await db.select(db.clientLogs).get(), hasLength(1));
  });

  test('UT-LO-05 書き出し：版と端末の行の後に、古い順に1行1件。問い合わせ番号を付ける', () async {
    await log.record('error', '一つ目', requestId: 'req-9');
    await log.record('info', '二つ目');
    final lines = (await log.exportText()).split('\n');
    expect(lines.first, startsWith('MeowScope '));
    expect(lines[1], '2026-11-03T10:00:00.000Z [error] 一つ目 (問い合わせ番号：req-9)');
    expect(lines[2], '2026-11-03T10:00:00.000Z [info] 二つ目');
  });

  test('UT-LO-17 版は画面と同じ出どころから読み、読めなければ unknown（#190）', () async {
    server.on('POST', '/client-logs', (r) => const FakeResponse(204));
    final withVersion = AppLog(db, version: () async => '1.0.2');
    await withVersion.record('info', 'a');
    expect(await withVersion.exportText(), startsWith('MeowScope 1.0.2 / '));
    await withVersion.send(fakeApiClient(server, tokens));
    final sent =
        ((server.sentTo('/client-logs').last.data as Map)['logs'] as List).first
            as Map;
    expect(sent['appVersion'], '1.0.2');

    final broken = AppLog(db, version: () async => throw Exception('no'));
    expect(await broken.exportText(), startsWith('MeowScope unknown / '));
  });

  group('同期と一緒に', () {
    late ProviderContainer container;

    setUp(() async {
      await db.batch(
        (b) => b.insertAll(db.appStates, [
          AppStatesCompanion.insert(key: 'session.userId', value: 'u1'),
          AppStatesCompanion.insert(key: 'session.userName', value: 'はる'),
        ]),
      );
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(fakeApiClient(server, tokens)),
        ],
      );
      // 見張る人がいないと止まるので、テストの間は見張っておく
      container.listen(authUserProvider, (_, _) {});
      await container.read(authUserProvider.future);
    });
    tearDown(() => container.dispose());

    Future<void> sync() =>
        container.read(syncControllerProvider.notifier).sync();

    test('UT-LO-06 サーバーの応答がある同期の失敗は、問い合わせ番号と一緒に記録する。つながらないだけなら記録しない', () async {
      server.on(
        'POST',
        '/sync',
        (r) => const FakeResponse(500, {
          'code': 'INTERNAL_ERROR',
          'requestId': 'req-7',
        }),
      );
      await sync();
      final row = await db.select(db.clientLogs).getSingle();
      expect((row.status, row.requestId), ('error', 'req-7'));
      expect(row.message, contains('500'));

      server.on(
        'POST',
        '/sync',
        (r) => const FakeResponse(400, {'code': 'VALIDATION_ERROR'}),
      );
      await sync();
      expect((await db.select(db.clientLogs).get()).last.status, 'warning');

      server.on('POST', '/sync', (r) => const FakeResponse.offline());
      await sync();
      expect(await db.select(db.clientLogs).get(), hasLength(2));
    });

    test('UT-LO-07 同期できたら、たまっているログを送る。想定外の例外は種類だけを記録する', () async {
      await log.record('warning', '前の失敗');
      server.on(
        'POST',
        '/sync',
        (r) => const FakeResponse(200, {
          'results': [],
          'changes': [],
          'nextSeq': 0,
          'hasMore': false,
          'fullResyncRequired': false,
        }),
      );
      server.on('POST', '/client-logs', (r) => const FakeResponse(204));
      await sync();
      expect(server.sentTo('/client-logs'), hasLength(1));
      expect(await db.select(db.clientLogs).get(), isEmpty);

      // 壊れた応答（想定外の例外）
      server.on(
        'POST',
        '/sync',
        (r) => const FakeResponse(200, {'results': 'broken'}),
      );
      await sync();
      final row = await db.select(db.clientLogs).getSingle();
      expect(row.status, 'error');
      expect(row.message, startsWith('同期で想定外の例外：'));
    });

    test(
      'UT-SY-38 異常系：同期の最中に部品が捨てられても（ログアウトなど）例外を出さず、ログの送信と通知をせずに終える（Issue #145）',
      () async {
        await log.record('warning', '前の失敗');
        server.on(
          'POST',
          '/sync',
          (r) => const FakeResponse(200, {
            'results': [],
            'changes': [],
            'nextSeq': 0,
            'hasMore': false,
            'fullResyncRequired': false,
          }),
        );
        server.on('POST', '/client-logs', (r) => const FakeResponse(204));
        // 同期の応答を待っている間に、部品の入れ物ごと捨てる（画面を閉じた・アプリを作り直したとき）
        Future<void> syncThenDispose(ProviderContainer c) async {
          c.listen(authUserProvider, (_, _) {});
          await c.read(authUserProvider.future);
          final running = c.read(syncControllerProvider.notifier).sync();
          c.dispose();
          await expectLater(running, completes);
        }

        await syncThenDispose(container);
        expect(server.sentTo('/client-logs'), isEmpty);

        // 想定外の例外のときも、例外のログを書かずに終える
        server.on(
          'POST',
          '/sync',
          (r) => const FakeResponse(200, {'results': 'broken'}),
        );
        await syncThenDispose(
          ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              tokenStoreProvider.overrideWithValue(tokens),
              apiClientProvider.overrideWithValue(
                fakeApiClient(server, tokens),
              ),
            ],
          ),
        );
        expect((await db.select(db.clientLogs).get()).map((r) => r.message), [
          '前の失敗',
        ]);
      },
    );
  });

  group('問い合わせ（S-06）', () {
    Future<void> show(
      WidgetTester tester, {
      String address = 'support@example.com',
      Future<String> Function(String)? saver,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            logFileSaverProvider.overrideWithValue(
              saver ?? (text) async => 'C:/logs/meowscope-log.txt',
            ),
          ],
          child: MaterialApp(home: ContactScreen(address: address)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('UT-LO-09 宛先を出し、ログを保存すると保存した場所を出す。コピーもできる', (tester) async {
      // クリップボードは OS の機能なので、テストでは受け取るだけの偽物にする
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      await show(tester);
      expect(find.text('問い合わせ先：support@example.com'), findsOneWidget);

      await tester.tap(find.text('ログを保存する'));
      await tester.pumpAndSettle();
      expect(find.text('保存しました：C:/logs/meowscope-log.txt'), findsOneWidget);
      // 前の案内が消えるのを待つ（案内は順に1つずつ出る）
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('宛先をコピーする'));
      await tester.pumpAndSettle();
      expect(find.text('宛先をコピーしました'), findsOneWidget);
    });

    testWidgets('UT-LO-10 異常系：保存できなければコピーを案内する。宛先が設定されていなければコピーを押せない', (
      tester,
    ) async {
      await show(
        tester,
        address: '',
        saver: (text) async => throw Exception('disk'),
      );
      expect(find.text('問い合わせ先：（このアプリには設定されていません）'), findsOneWidget);
      final copy = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '宛先をコピーする'),
      );
      expect(copy.onPressed, isNull);

      await tester.tap(find.text('ログを保存する'));
      await tester.pumpAndSettle();
      expect(find.text('保存できませんでした。「ログをコピーする」を使ってください'), findsOneWidget);
    });
  });
}
