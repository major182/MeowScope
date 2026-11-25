import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowscope/core/db/app_database.dart';
import 'package:meowscope/core/providers.dart';
import 'package:meowscope/core/today.dart';
import 'package:meowscope/features/auth/data/token_store.dart';
import 'package:meowscope/features/export/presentation/csv_export_screen.dart';
import 'package:meowscope/main.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_db.dart';

/// 記録の CSV の出力（S-52。F-EX-01、BR-41）
void main() {
  late AppDatabase db;
  late FakeServer server;
  late MemoryTokenStore tokens;
  late Directory dir;
  final now = DateTime(2026, 11, 25, 10);

  /// 保存の画面で選ばれた場所。null ならやめた
  String? chosen;

  /// 保存の画面に渡された名前の案
  String? suggested;

  Future<void> record(String id, String catId, String typeId, DateTime at) => db
      .into(db.records)
      .insert(
        RecordsCompanion.insert(
          id: id,
          createdAt: testTime,
          updatedAt: testTime,
          catId: catId,
          recordTypeId: typeId,
          recordedAt: at.toUtc(),
          authorName: 'はる',
        ),
      );

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
    dir = await Directory.systemTemp.createTemp('meowscope_csv_');
    chosen = '${dir.path}${Platform.pathSeparator}out.csv';
    suggested = null;
    await addHousehold(db, 'h1');
    await addHousehold(db, 'h2');
    await addCat(db, id: 'c1', householdId: 'h1', name: 'ミケ');
    await addCat(db, id: 'c2', householdId: 'h1', name: 'タマ');
    await addCat(db, id: 'c9', householdId: 'h2', name: 'よそ');
    for (final (id, household, name) in [
      ('t1', 'h1', 'ご飯'),
      ('t2', 'h1', '水'),
      ('t9', 'h2', 'ご飯'),
    ]) {
      await db
          .into(db.recordTypes)
          .insert(
            RecordTypesCompanion.insert(
              id: id,
              createdAt: testTime,
              updatedAt: testTime,
              householdId: household,
              name: name,
              kind: 'custom',
              sortOrder: Value(id == 't1' ? 0 : 1),
            ),
          );
    }
    await record('r1', 'c1', 't1', DateTime(2026, 11, 1, 8));
    await record('r2', 'c2', 't2', DateTime(2026, 11, 3, 9));
    await record('r3', 'c1', 't2', DateTime(2026, 11, 20, 7));
    // ほかのおうちの記録は出さない
    await record('r9', 'c9', 't9', DateTime(2026, 11, 2, 8));
    await db.batch(
      (b) => b.insertAll(db.appStates, [
        AppStatesCompanion.insert(key: 'session.userId', value: 'u1'),
        AppStatesCompanion.insert(key: 'session.userName', value: 'はる'),
        AppStatesCompanion.insert(key: 'session.householdId', value: 'h1'),
      ]),
    );
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> start(WidgetTester tester, {bool windows = true}) async {
    debugDefaultTargetPlatformOverride = windows
        ? TargetPlatform.windows
        : TargetPlatform.android;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(fakeApiClient(server, tokens)),
          nowProvider.overrideWithValue(() => now),
          csvSaveLocationProvider.overrideWithValue((name) async {
            suggested = name;
            return chosen;
          }),
        ],
        child: const MeowScopeApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('CSV の出力'), 100);
    await tester.tap(find.text('CSV の出力'));
    await tester.pumpAndSettle();
  }

  Future<void> export(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'CSV を出力');
    await tester.ensureVisible(button);
    await tester.tap(button);
    // ファイルへの書き込みは本物の入出力なので、本物の時計で少し待っては画面を進める。
    // 書き終わってボタンがまた押せるようになるまで繰り返す
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (tester.widget<FilledButton>(button).onPressed != null) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  /// 書いたファイルの行。先頭の3バイトが BOM（EF BB BF）であることも確かめる。
  /// 読むのは本物の入出力なので runAsync の中で行う
  Future<List<String>> written(WidgetTester tester) async {
    final bytes = (await tester.runAsync(() => File(chosen!).readAsBytes()))!;
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    return utf8.decode(bytes.sublist(3)).trimRight().split('\r\n');
  }

  testWidgets('UT-EX-04 Windows だけ設定に入口を出す（Android には出さない）', (tester) async {
    await start(tester, windows: false);
    expect(find.text('CSV の出力'), findsNothing);
    await close(tester);

    await start(tester);
    await tester.scrollUntilVisible(find.text('CSV の出力'), 100);
    expect(find.text('CSV の出力'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-EX-05 全期間・すべての猫と項目で、今のおうちの記録を古い順に保存する', (tester) async {
    await start(tester);
    await open(tester);
    await export(tester);

    expect(suggested, 'meowscope_20261125.csv');
    final rows = await written(tester);
    expect(rows.first, startsWith('日付,時刻,猫,項目'));
    expect(
      [for (final r in rows.skip(1)) r.split(',').take(4).join(',')],
      [
        '2026-11-01,08:00,ミケ,ご飯',
        '2026-11-03,09:00,タマ,水',
        '2026-11-20,07:00,ミケ,水',
      ],
    );
    expect(find.text('CSV を保存しました（3件）'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-EX-10 メモに改行があっても、保存した件数は記録の数で出す', (tester) async {
    await (db.update(db.records)..where((r) => r.id.equals('r1'))).write(
      const RecordsCompanion(memo: Value('1行目\r\n2行目')),
    );
    await start(tester);
    await open(tester);
    await export(tester);

    expect(find.text('CSV を保存しました（3件）'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-EX-06猫と項目を絞ると、選んだものだけを出す。1つも選ばなければ出力できない', (tester) async {
    await start(tester);
    await open(tester);

    await tester.tap(find.widgetWithText(SwitchListTile, 'すべての猫'));
    await tester.pumpAndSettle();
    expect(find.text('1つ以上選んでください'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'CSV を出力');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'ミケ'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(SwitchListTile, 'すべての項目'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'すべての項目'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(CheckboxListTile, '水'));
    await tester.tap(find.widgetWithText(CheckboxListTile, '水'));
    await tester.pumpAndSettle();
    await export(tester);

    final rows = await written(tester);
    expect(rows, hasLength(2));
    expect(rows[1], startsWith('2026-11-20,07:00,ミケ,水'));
    await close(tester);
  });

  testWidgets('UT-EX-07 期間を指定するなら両端を選ぶまで出力できない', (tester) async {
    await start(tester);
    await open(tester);

    await tester.tap(find.text('期間を指定'));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'CSV を出力');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('開始日'), findsOneWidget);
    expect(find.text('終了日'), findsOneWidget);
    await close(tester);
  });

  testWidgets('UT-EX-08 保存の画面でやめたら保存しない。拡張子がなければ .csv を付ける', (tester) async {
    await start(tester);
    await open(tester);

    final path = chosen!;
    chosen = null;
    await export(tester);
    expect(File(path).existsSync(), isFalse);
    expect(find.textContaining('CSV を保存しました'), findsNothing);

    chosen = '${dir.path}${Platform.pathSeparator}noext';
    await export(tester);
    expect(
      File('${dir.path}${Platform.pathSeparator}noext.csv').existsSync(),
      isTrue,
    );
    await close(tester);
  });

  testWidgets('UT-EX-09 異常系：書き込めない場所なら、別の場所か名前で試すよう案内する', (tester) async {
    await start(tester);
    await open(tester);

    // ないフォルダーの中は書き込めない
    chosen =
        '${dir.path}${Platform.pathSeparator}none${Platform.pathSeparator}out.csv';
    await export(tester);
    expect(find.text('保存できませんでした。別の場所か名前でお試しください'), findsOneWidget);
    await close(tester);
  });
}
