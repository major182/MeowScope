import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/main.dart';

import '../../test/helpers/fake_api.dart' show MemoryTokenStore;
import '../../test/helpers/test_db.dart' show memoryDatabase;

/// E2E テストの中で動かすアプリ。本物のサーバーにつなぎ、端末の DB とトークンの置き場だけをメモリーに差し替える
/// （利用者の端末のデータを使わず、毎回まっさらから始めるため。本体の設定は変えない）
class E2eApp {
  E2eApp() : db = memoryDatabase(), tokens = MemoryTokenStore();

  final AppDatabase db;
  final MemoryTokenStore tokens;

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(tokens),
        ],
        child: const MeowScopeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  }
}

/// 本物の通信は pumpAndSettle では待てないので、[finder] が出るまで少しずつ進めて待つ
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  throw TestFailure('待っても出なかった：$finder');
}

/// [action] を、[done] が真になるまで繰り返す（サーバーへの反映を待つ）
Future<T> eventually<T>(
  Future<T> Function() action,
  bool Function(T) done, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (true) {
    final value = await action();
    if (done(value) || DateTime.now().isAfter(end)) {
      return value;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), value);
  await tester.pump();
}
