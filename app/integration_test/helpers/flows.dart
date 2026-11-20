import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_app.dart';

/// E2E テストで共通に使う操作の流れ（e2e_test.dart と v13_e2e_test.dart から使う）

/// E2E のアカウントのパスワード
const e2ePassword = 'Passw0rd!';

/// ログインの画面から新規登録し、おうちの準備の画面まで進む
Future<void> register(WidgetTester tester, String email, String name) async {
  await tapText(tester, '新規アカウント作成');
  await enter(tester, '名前', name);
  await enter(tester, 'メールアドレス', email);
  await enter(tester, 'パスワード（8〜64文字）', e2ePassword);
  await tester.tap(find.widgetWithText(FilledButton, '登録する'));
  await waitFor(tester, find.text('おうちを準備します'));
}

/// おうち（E2E家）と猫（ミケ）を作り、ホームまで進む
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
