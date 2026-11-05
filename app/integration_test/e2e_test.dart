import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e_app.dart';
import 'helpers/server_api.dart';

/// E2E テスト（NF-MT-02、AC-18）。本物のサーバーにつなぎ、主要な操作を画面から行う
///
/// 動かし方は tool/e2e.dart（テスト仕様書 6章）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final api = ServerApi();
  const password = 'Passw0rd!';
  final android = defaultTargetPlatform == TargetPlatform.android;

  Future<void> register(WidgetTester tester, String email, String name) async {
    await tapText(tester, '新規アカウント作成');
    await enter(tester, '名前', name);
    await enter(tester, 'メールアドレス', email);
    await enter(tester, 'パスワード（8〜64文字）', password);
    await tester.tap(find.widgetWithText(FilledButton, '登録する'));
    await waitFor(tester, find.text('おうちを準備します'));
  }

  Future<void> createHouseholdAndCat(WidgetTester tester) async {
    await enter(tester, 'おうちの名前', 'E2E家');
    await tester.tap(find.widgetWithText(FilledButton, '新しいおうちを作る'));
    await waitFor(tester, find.text('猫を登録しましょう'));
    await enter(tester, '名前', 'ミケ');
    await tester.tap(find.widgetWithText(FilledButton, '登録する'));
    // ホームの見出しはおうち名（S-10）
    await waitFor(tester, find.widgetWithText(AppBar, 'E2E家'));
  }

  /// 設定の同期の状態から今すぐ同期し、未送信が 0 件になるまで待つ
  Future<void> syncNow(WidgetTester tester) async {
    await tapText(tester, '設定');
    await tapText(tester, '同期の状態');
    await tester.tap(find.widgetWithText(FilledButton, '今すぐ同期'));
    await waitFor(tester, find.text('0件'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'E2E-01 使い始め：新規登録 → おうちの作成 → 猫の登録 → 記録 → 詳細の入力 → カレンダー・統計 → 同期でサーバーに届く',
    (tester) async {
      final app = E2eApp();
      final email = ServerApi.uniqueEmail('first');
      await app.start(tester);
      await register(tester, email, 'はる');
      await createHouseholdAndCat(tester);

      // 記録（猫が1匹なので選ばずに保存する）
      await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
      await waitFor(tester, find.text('ミケ　ご飯'));

      // 詳細を入れる
      await tapText(tester, 'ミケ　ご飯');
      expect(find.text('記録の詳細'), findsOneWidget);
      await tapText(tester, '編集');
      await enter(tester, 'メモ', '完食');
      await tapText(tester, '保存');
      await waitFor(tester, find.textContaining('完食'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('メモ：完食'), findsOneWidget);

      // カレンダーと統計を開ける
      await tapText(tester, 'カレンダー');
      expect(find.widgetWithText(AppBar, 'カレンダー'), findsOneWidget);
      await tapText(tester, '統計');
      expect(find.widgetWithText(AppBar, '統計'), findsOneWidget);
      await tapText(tester, 'ホーム');

      // 同期して、サーバーに記録とメモが届いたことを確かめる
      await syncNow(tester);
      final token = await api.login(email, password);
      final changes = await api.sync(token);
      final records = [
        for (final c in changes)
          if (c['table'] == 'records') c['data'] as Map,
      ];
      expect(records, hasLength(1));
      expect(records.single['memo'], '完食');
      expect(records.single['authorName'], 'はる');
      await app.close(tester);
    },
  );

  testWidgets('E2E-02 家族で共有：家族が作ったおうちに招待の文で参加し、家族の記録が届き、自分の記録が家族に届く', (
    tester,
  ) async {
    // 家族（なつ）はサーバーの API で、おうち・猫・記録・招待のリンクを作る
    final familyToken = await api.register(
      ServerApi.uniqueEmail('family'),
      password,
      'なつ',
    );
    final ids = await api.createHousehold(familyToken, 'なつ家');
    await api.addCatAndRecord(
      familyToken,
      household: ids.household,
      catName: 'タマ',
      typeId: ids.food,
      authorName: 'なつ',
    );
    final link = await api.invite(familyToken, ids.household);

    // 自分（はる）はアプリで登録し、招待の文で参加する
    final app = E2eApp();
    await app.start(tester);
    await register(tester, ServerApi.uniqueEmail('member'), 'はる');
    await tapText(tester, '招待されたおうちに参加');
    await tester.enterText(find.byType(TextField), 'なつ家に招待されました\n$link');
    await tester.tap(find.widgetWithText(FilledButton, '参加する'));

    // 家族の記録が届く
    await waitFor(tester, find.text('タマ　ご飯'));

    // 自分の記録が家族に届く
    await tester.tap(find.widgetWithText(OutlinedButton, '水'));
    await waitFor(tester, find.text('タマ　水'));
    await syncNow(tester);
    final received = await eventually(
      () => api.sync(familyToken),
      (changes) => changes.any(
        (c) =>
            c['table'] == 'records' &&
            (c['data'] as Map)['recordTypeId'] == ids.water,
      ),
    );
    final mine = received.firstWhere(
      (c) =>
          c['table'] == 'records' &&
          (c['data'] as Map)['recordTypeId'] == ids.water,
    );
    expect((mine['data'] as Map)['authorName'], 'はる');
    await app.close(tester);
  });

  testWidgets(
    'E2E-03 機種変更：ログアウトしてログインし直すと、おうち・猫・記録（Android はウィジェットのボタンも）が戻る（AC-13）',
    (tester) async {
      final app = E2eApp();
      final email = ServerApi.uniqueEmail('device');
      await app.start(tester);
      await register(tester, email, 'はる');
      await createHouseholdAndCat(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
      await waitFor(tester, find.text('ミケ　ご飯'));
      if (android) {
        await tapText(tester, '設定');
        await tapText(tester, 'ウィジェットのボタン');
        await tapText(tester, 'ボタンを追加');
        await tester.tap(find.widgetWithText(SimpleDialogOption, '水'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tapText(tester, 'ホーム');
      }
      await syncNow(tester);

      // ログアウトして、同じアカウントでログインし直す
      await tapText(tester, '設定');
      await tapText(tester, 'アカウント');
      await tapText(tester, 'ログアウト');
      await waitFor(tester, find.widgetWithText(FilledButton, 'ログイン'));
      expect(await app.db.select(app.db.records).get(), isEmpty);

      await enter(tester, 'メールアドレス', email);
      await enter(tester, 'パスワード', password);
      await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
      await waitFor(tester, find.text('ミケ　ご飯'));

      if (android) {
        await tapText(tester, '設定');
        await tapText(tester, 'ウィジェットのボタン');
        expect(find.text('水'), findsWidgets);
        expect(find.text('ボタンがありません'), findsNothing);
      }
      await app.close(tester);
    },
  );
}
