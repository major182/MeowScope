import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meowscope/core/api/api_client.dart' show apiBaseUrl;
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../integration_test/helpers/e2e_app.dart' show RecordingNotifier;
import '../test/helpers/fake_api.dart' show MemoryTokenStore;

/// PT-07：5年分の記録で、アプリの操作の速さを測る（NF-PF-02・04。性能テストの設計書 4章）
///
/// 動かし方は perf/run.ts（profile ビルドで flutter run する）。結果は `PERF_RESULT {...}` の1行で出す。
/// 端末の DB はファイルに置き（起動の時間に読み込みを含めるため）、テストの初めに消す。トークンだけはメモリーに置く
const _years = int.fromEnvironment('PERF_YEARS', defaultValue: 5);
const _repeat = 3;
const _password = 'Passw0rd!';
const _uuid = Uuid();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PT-07 アプリの操作の速さ（$_years年分）', (tester) async {
    final results = <String, List<int>>{};
    void add(String name, Stopwatch s) =>
        (results[name] ??= []).add(s.elapsedMilliseconds);

    final email = await _seed();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/meowscope-perf.sqlite');
    if (file.existsSync()) file.deleteSync();
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.createInBackground(file),
        closeStreamsSynchronously: true,
      ),
    );
    final tokens = MemoryTokenStore();
    final notifier = RecordingNotifier();
    Widget app() => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(tokens),
        notifierProvider.overrideWithValue(notifier),
      ],
      child: const MeowScopeApp(),
    );
    final home = find.widgetWithText(AppBar, '性能の家');

    // ログインして、5年分を全件受け取る（新しい端末の初めての同期）
    await tester.pumpWidget(app());
    await _settle(tester);
    // profile ビルドではテストからのキーボードの入力が届かないので、入力欄の中身を直接入れる
    tester
            .widget<EditableText>(find.byType(EditableText).at(0))
            .controller
            .text =
        email;
    await _settle(tester);
    tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .controller
            .text =
        _password;
    await _settle(tester);
    // 入力欄から離れる（カーソルの点滅が続くと、画面が落ち着かない）
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(tester);
    var s = Stopwatch()..start();
    await tester.tap(find.widgetWithText(FilledButton, 'ログイン'));
    try {
      await _until(tester, home);
    } on TestFailure {
      // 原因を調べられるよう、出ている文字を残す
      // ignore: avoid_print
      print(
        '画面の文字：${[for (final e in find.byType(Text).evaluate()) (e.widget as Text).data]}',
      );
      rethrow;
    }
    await _waitRecords(db, tester);
    add('初めての全件の同期', s);

    for (var i = 0; i < _repeat; i++) {
      // 起動からホームの表示まで（NF-PF-02：3秒以内）。画面を作り直し、DB とトークンはそのまま
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
      s = Stopwatch()..start();
      await tester.pumpWidget(app());
      await _until(tester, home);
      add('起動からホームの表示', s);
      await _settle(tester);

      // 記録の保存（NF-PF-02：0.5秒以内）。押してからホームの一覧に出るまで
      final before = find.text('ミケ　ご飯').evaluate().length;
      s = Stopwatch()..start();
      await tester.tap(find.widgetWithText(OutlinedButton, 'ご飯'));
      await _untilTrue(
        tester,
        () => find.text('ミケ　ご飯').evaluate().length > before,
      );
      add('記録の保存', s);
      await _settle(tester);

      // カレンダー：開く・前の月へ切り替える（NF-PF-04）
      s = Stopwatch()..start();
      await tester.tap(find.text('カレンダー').last);
      await _settle(tester);
      add('カレンダーを開く', s);
      s = Stopwatch()..start();
      await tester.tap(find.byTooltip('前の月'));
      await _settle(tester);
      add('カレンダーの月の切り替え', s);

      // 統計：開く（体調のようすまで）・体調のようすの日付の切り替え
      s = Stopwatch()..start();
      await tester.tap(find.text('統計').last);
      await _until(tester, find.text('体調のようす'));
      await _settle(tester);
      add('統計を開く', s);
      s = Stopwatch()..start();
      await tester.tap(find.byTooltip('前の日'));
      await _settle(tester);
      add('体調のようすの日付の切り替え', s);
      await tester.tap(find.text('ホーム').last);
      await _settle(tester);
    }

    final records = await db.select(db.records).get();
    // ignore: avoid_print
    print(
      'PERF_RESULT ${jsonEncode({'years': _years, 'records': records.length, 'platform': Platform.operatingSystem, 'ms': results})}',
    );
    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
    await db.close();
    file.deleteSync();
  }, timeout: const Timeout(Duration(minutes: 30)));
}

/// 描く予定のフレームがなくなるまで進める（pumpAndSettle は、動き続けるものがあると終わらないため、最長5秒で打ち切る）
Future<void> _settle(WidgetTester tester) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  do {
    await tester.pump(const Duration(milliseconds: 16));
  } while (tester.binding.hasScheduledFrame && DateTime.now().isBefore(end));
}

/// [finder] が出るまで、1フレームずつ進める（pumpAndSettle の待ちを測る時間に入れない）
Future<void> _until(WidgetTester tester, Finder finder) =>
    _untilTrue(tester, () => finder.evaluate().isNotEmpty);

Future<void> _untilTrue(WidgetTester tester, bool Function() done) async {
  final end = DateTime.now().add(const Duration(minutes: 2));
  while (!done()) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('待っても出なかった');
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// 端末の DB に5年分が入るまで待つ（ホームが出た後も、続きのページを受け取っている）
Future<void> _waitRecords(AppDatabase db, WidgetTester tester) async {
  final want = _years * 365 * 14;
  final end = DateTime.now().add(const Duration(minutes: 5));
  while ((await db.select(db.records).get()).length < want) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('全件を受け取れなかった');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// 性能テスト専用のサーバーに、目印つきの利用者と5年分のおうちを作る（perf/src/bulk-sync.ts と同じ形）
Future<String> _seed() async {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  final email = 'perf-${_uuid.v4().substring(0, 8)}-app@example.test';
  final token =
      (await dio.post<Map<String, dynamic>>(
            '/auth/register',
            data: {'email': email, 'password': _password, 'displayName': '性能'},
          )).data!['accessToken']
          as String;
  final auth = Options(headers: {'Authorization': 'Bearer $token'});
  const kinds = [
    ('food', 'ご飯', 'food'),
    ('water', '水', 'water'),
    ('medicine', '薬', 'medicine'),
    ('urine', 'おしっこ', 'pee'),
    ('stool', 'うんち', 'poop'),
    ('vomit', '吐いた', 'vomit'),
    ('weight', '体重', 'weight'),
    ('brushing', 'ブラシ', 'brushing'),
  ];
  final household = _uuid.v4();
  final types = {for (final k in kinds) k.$1: _uuid.v4()};
  await dio.post<void>(
    '/households',
    data: {
      'id': household,
      'name': '性能の家',
      'recordTypes': [
        for (final (i, k) in kinds.indexed)
          {
            'id': types[k.$1],
            'name': k.$2,
            'icon': k.$3,
            'kind': k.$1,
            'sortOrder': i,
          },
      ],
    },
    options: auth,
  );
  final cat = _uuid.v4();
  final now = DateTime.now().toUtc().toIso8601String();
  Map<String, Object?> change(
    String table,
    String id,
    Map<String, Object?> d,
  ) => {
    'table': table,
    'id': id,
    'updatedAt': now,
    'deletedAt': null,
    'data': d,
  };
  Future<void> send(List<Map<String, Object?>> changes) => dio.post<void>(
    '/sync',
    data: {'lastSeq': 0, 'changes': changes},
    options: auth,
  );
  await send([
    change('cats', cat, {
      'householdId': household,
      'name': 'ミケ',
      'status': 'active',
    }),
  ]);
  final today = DateTime.now();
  var batch = <Map<String, Object?>>[];
  for (var d = 1; d <= _years * 365; d++) {
    final plan = <(String, List<int>)>[
      ('food', [7, 12, 19]),
      ('water', [8, 10, 13, 16, 20]),
      ('urine', [9, 14, 21]),
      ('stool', [11, 22]),
      ('brushing', [18]),
      if (d % 3 == 0) ('weight', [23]),
      if (d % 20 == 0) ('vomit', [6]),
    ];
    for (final (kind, hours) in plan) {
      for (final h in hours) {
        final at = DateTime(today.year, today.month, today.day - d, h);
        batch.add(
          change('records', _uuid.v4(), {
            'catId': cat,
            'recordTypeId': types[kind],
            'recordedAt': at.toUtc().toIso8601String(),
            'authorName': '性能',
            if (kind == 'weight') 'valueNumber': 4.0 + (d % 5) / 10,
          }),
        );
        if (batch.length == 500) {
          await send(batch);
          batch = [];
        }
      }
    }
  }
  if (batch.isNotEmpty) await send(batch);
  return email;
}
